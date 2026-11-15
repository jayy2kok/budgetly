package com.budgetly.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.repository.CategoryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class CategoryResolverTest {

    private CategoryRepository categoryRepository;
    private CategoryResolver resolver;

    @BeforeEach
    void setUp() {
        categoryRepository = mock(CategoryRepository.class);
        resolver = new CategoryResolver(categoryRepository);
    }

    private CategoryDocument category(String id, String name) {
        return CategoryDocument.builder().id(id).name(name).build();
    }

    // ── familyCategories ─────────────────────────────────────────

    @Test
    void familyCategoriesFetchesForNonNullFamily() {
        when(categoryRepository.findByFamilyGroupIdOrderBySortOrderAsc("fam-1"))
                .thenReturn(List.of(category("c1", "Groceries")));

        assertThat(resolver.familyCategories("fam-1")).extracting(CategoryDocument::getId)
                .containsExactly("c1");
        verify(categoryRepository).findByFamilyGroupIdOrderBySortOrderAsc("fam-1");
    }

    @Test
    void familyCategoriesSkipsRepositoryForNullFamily() {
        assertThat(resolver.familyCategories(null)).isEmpty();
        assertThat(resolver.familyCategories("  ")).isEmpty();
        verify(categoryRepository, never()).findByFamilyGroupIdOrderBySortOrderAsc(anyString());
    }

    // ── namesForPrompt ───────────────────────────────────────────

    @Test
    void namesForPromptUsesFamilyNamesWhenPresent() {
        List<CategoryDocument> cats = List.of(category("c1", "Groceries"), category("c2", "Dining"));

        assertThat(resolver.namesForPrompt(cats)).containsExactly("Groceries", "Dining");
    }

    @Test
    void namesForPromptFallsBackToDefaultListWhenFamilyHasNone() {
        assertThat(resolver.namesForPrompt(List.of())).isEqualTo(CategoryResolver.DEFAULT_CATEGORIES);
    }

    @Test
    void namesForPromptFiltersBlankNamesBeforeFallingBack() {
        List<CategoryDocument> cats = List.of(category("c1", null), category("c2", "  "));

        assertThat(resolver.namesForPrompt(cats)).isEqualTo(CategoryResolver.DEFAULT_CATEGORIES);
    }

    // ── categoryIdFor ────────────────────────────────────────────

    @Test
    void categoryIdForMatchesCaseInsensitively() {
        List<CategoryDocument> cats = List.of(category("c1", "Groceries"), category("c2", "Dining"));

        assertThat(resolver.categoryIdFor(cats, "groceriES")).isEqualTo("c1");
        assertThat(resolver.categoryIdFor(cats, "dining")).isEqualTo("c2");
    }

    @Test
    void categoryIdForReturnsNullForUncategorized() {
        List<CategoryDocument> cats = List.of(category("c1", "Groceries"));

        assertThat(resolver.categoryIdFor(cats, "uncategorized")).isNull();
        assertThat(resolver.categoryIdFor(cats, "Uncategorized")).isNull();
    }

    @Test
    void categoryIdForReturnsNullForBlank() {
        List<CategoryDocument> cats = List.of(category("c1", "Groceries"));

        assertThat(resolver.categoryIdFor(cats, null)).isNull();
        assertThat(resolver.categoryIdFor(cats, "   ")).isNull();
    }

    @Test
    void categoryIdForReturnsNullWhenNoMatch() {
        List<CategoryDocument> cats = List.of(category("c1", "Groceries"));

        assertThat(resolver.categoryIdFor(cats, "Unknown Category")).isNull();
    }

    @Test
    void categoryIdForReturnsNullWhenFamilyHasNoCategories() {
        assertThat(resolver.categoryIdFor(List.of(), "Groceries")).isNull();
    }
}