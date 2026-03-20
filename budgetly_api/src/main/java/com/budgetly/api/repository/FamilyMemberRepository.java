package com.budgetly.api.repository;

import com.budgetly.api.document.FamilyMemberDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FamilyMemberRepository extends MongoRepository<FamilyMemberDocument, String> {
    List<FamilyMemberDocument> findByFamilyGroupId(String familyGroupId);
    Optional<FamilyMemberDocument> findByUserIdAndFamilyGroupId(String userId, String familyGroupId);
    List<FamilyMemberDocument> findByUserId(String userId);
    boolean existsByUserIdAndFamilyGroupId(String userId, String familyGroupId);
}
