package com.budgetly.api.service;

import com.budgetly.api.document.CategoryDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.Category;
import com.budgetly.api.generated.model.CreateCategoryRequest;
import com.budgetly.api.generated.model.UpdateCategoryRequest;
import com.budgetly.api.repository.CategoryRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final FamilyMemberRepository familyMemberRepository;
    private final TransactionRepository transactionRepository;

    public List<Category> listCategories(String userId, String familyId) {
        requireMember(userId, familyId);
        return categoryRepository.findByFamilyGroupIdOrderBySortOrderAsc(familyId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    public Category createCategory(String userId, String familyId, CreateCategoryRequest request) {
        requireAdmin(userId, familyId);
        CategoryDocument doc = CategoryDocument.builder()
                .familyGroupId(familyId)
                .name(request.getName())
                .icon(request.getIcon())
                .budgetLimit(request.getBudgetLimit() != null ? request.getBudgetLimit() : 0.0)
                .color(request.getColor())
                .sortOrder(request.getSortOrder() != null ? request.getSortOrder() : 0)
                .build();
        return toDto(categoryRepository.save(doc));
    }

    public Category updateCategory(String userId, String familyId, String categoryId, UpdateCategoryRequest request) {
        requireAdmin(userId, familyId);
        CategoryDocument doc = categoryRepository.findByIdAndFamilyGroupId(categoryId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Category", categoryId));

        if (request.getName() != null) doc.setName(request.getName());
        if (request.getIcon() != null) doc.setIcon(request.getIcon());
        if (request.getBudgetLimit() != null) doc.setBudgetLimit(request.getBudgetLimit());
        if (request.getColor() != null) doc.setColor(request.getColor());
        if (request.getSortOrder() != null) doc.setSortOrder(request.getSortOrder());

        return toDto(categoryRepository.save(doc));
    }

    public void deleteCategory(String userId, String familyId, String categoryId) {
        requireAdmin(userId, familyId);
        categoryRepository.findByIdAndFamilyGroupId(categoryId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Category", categoryId));

        // Reassign transactions to null (uncategorized)
        transactionRepository.deleteAllByCategoryId(categoryId);  // optional: reassign instead
        categoryRepository.deleteById(categoryId);
    }

    public CategoryDocument getCategoryDocument(String familyId, String categoryId) {
        return categoryRepository.findByIdAndFamilyGroupId(categoryId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("Category", categoryId));
    }

    // ── Helpers ──────────────────────────────────────────────────

    private void requireMember(String userId, String familyId) {
        if (!familyMemberRepository.existsByUserIdAndFamilyGroupId(userId, familyId)) {
            throw new ForbiddenException("Not a member of this family");
        }
    }

    private void requireAdmin(String userId, String familyId) {
        var member = familyMemberRepository.findByUserIdAndFamilyGroupId(userId, familyId)
                .orElseThrow(() -> new ForbiddenException("Not a member of this family"));
        if (!"ADMIN".equals(member.getRole())) {
            throw new ForbiddenException("Admin role required");
        }
    }

    public Category toDto(CategoryDocument doc) {
        Category dto = new Category();
        dto.setId(doc.getId());
        dto.setFamilyGroupId(doc.getFamilyGroupId());
        dto.setName(doc.getName());
        dto.setIcon(doc.getIcon());
        dto.setBudgetLimit(doc.getBudgetLimit());
        dto.setColor(doc.getColor());
        dto.setSortOrder(doc.getSortOrder());
        return dto;
    }
}
