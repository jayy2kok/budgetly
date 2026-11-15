package com.budgetly.api.service;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Bridges the LLM step and the persisted category model.
 *
 * <p>Both LLM consumers (the change-stream slow path and the {@code /messages/process}
 * endpoint) need two things: the category names to offer the LLM in the prompt, and a
 * way to translate the LLM's chosen category name back into a real {@code CategoryDocument}
 * id for the message's family. This component centralises the lookup so both share the same
 * rules:
 * <ul>
 *   <li>prefer the family-group's configured categories;</li>
 *   <li>fall back to a built-in default list when the family has none (or no family is set);</li>
 *   <li>map the returned name case-insensitively; anything unrecognised (or the literal
 *       {@code "uncategorized"}) resolves to {@code null} → the app renders it as
 *       "Uncategorized".</li>
 * </ul>
 */
@Component
@RequiredArgsConstructor
public class CategoryResolver {

    /** Sentinel the LLM is instructed to return when it cannot pick a category. */
    public static final String UNCATEGORIZED = "uncategorized";

    /** Built-in fallback list used when a family has no configured categories. */
    public static final List<String> DEFAULT_CATEGORIES = List.of(
            "Groceries", "Dining", "Transport", "Shopping", "Utilities",
            "Health", "Entertainment", "Travel", "Rent", "Fuel",
            "Salary", "Investment", "Other");

    private final CategoryRepository categoryRepository;

    /**
     * The family's configured categories, ordered by sort order. Empty when
     * {@code familyGroupId} is {@code null}/blank or the family has none.
     */
    public List<CategoryDocument> familyCategories(String familyGroupId) {
        if (familyGroupId == null || familyGroupId.isBlank()) {
            return List.of();
        }
        return categoryRepository.findByFamilyGroupIdOrderBySortOrderAsc(familyGroupId);
    }

    /**
     * The category names to put in the LLM prompt: the family's configured names, or
     * {@link #DEFAULT_CATEGORIES} when the family list is empty.
     */
    public List<String> namesForPrompt(List<CategoryDocument> familyCategories) {
        List<String> names = familyCategories.stream()
                .map(CategoryDocument::getName)
                .filter(n -> n != null && !n.isBlank())
                .collect(Collectors.toList());
        return names.isEmpty() ? DEFAULT_CATEGORIES : names;
    }

    /**
     * Maps an LLM-returned category name to the matching family category id,
     * case-insensitively. Returns {@code null} (→ "Uncategorized" in the app) when
     * the name is blank, is the literal {@code "uncategorized"}, or matches no
     * family category.
     */
    public String categoryIdFor(List<CategoryDocument> familyCategories, String llmCategory) {
        if (llmCategory == null || llmCategory.isBlank()) {
            return null;
        }
        String trimmed = llmCategory.trim();
        if (UNCATEGORIZED.equalsIgnoreCase(trimmed)) {
            return null;
        }
        return familyCategories.stream()
                .filter(c -> trimmed.equalsIgnoreCase(c.getName()))
                .map(CategoryDocument::getId)
                .findFirst()
                .orElse(null);
    }
}