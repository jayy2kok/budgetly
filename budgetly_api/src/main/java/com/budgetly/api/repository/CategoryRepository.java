package com.budgetly.api.repository;

import com.budgetly.api.document.CategoryDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoryRepository extends MongoRepository<CategoryDocument, String> {
    List<CategoryDocument> findByFamilyGroupIdOrderBySortOrderAsc(String familyGroupId);
    Optional<CategoryDocument> findByIdAndFamilyGroupId(String id, String familyGroupId);
    boolean existsByFamilyGroupIdAndName(String familyGroupId, String name);
}
