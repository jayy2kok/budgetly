package com.budgetly.api.repository;

import com.budgetly.api.document.HiddenPatternDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface HiddenPatternRepository extends MongoRepository<HiddenPatternDocument, String> {
    List<HiddenPatternDocument> findByFamilyGroupId(String familyGroupId);
    Optional<HiddenPatternDocument> findByFamilyGroupIdAndPatternId(String familyGroupId, String patternId);
    void deleteByFamilyGroupIdAndPatternId(String familyGroupId, String patternId);
}
