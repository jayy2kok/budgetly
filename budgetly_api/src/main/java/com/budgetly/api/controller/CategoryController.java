package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.CategoriesApi;
import com.budgetly.api.generated.model.Category;
import com.budgetly.api.generated.model.CreateCategoryRequest;
import com.budgetly.api.generated.model.UpdateCategoryRequest;
import com.budgetly.api.service.CategoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CategoryController implements CategoriesApi {

    private final CategoryService categoryService;

    @Override
    public ResponseEntity<List<Category>> listCategories(String fid) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(categoryService.listCategories(userId, fid));
    }

    @Override
    public ResponseEntity<Category> createCategory(String fid, CreateCategoryRequest createCategoryRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(categoryService.createCategory(userId, fid, createCategoryRequest));
    }

    @Override
    public ResponseEntity<Category> updateCategory(String fid, String id, UpdateCategoryRequest updateCategoryRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(categoryService.updateCategory(userId, fid, id, updateCategoryRequest));
    }

    @Override
    public ResponseEntity<Void> deleteCategory(String fid, String id) {
        String userId = ControllerUtils.getCurrentUserId();
        categoryService.deleteCategory(userId, fid, id);
        return ResponseEntity.noContent().build();
    }
}
