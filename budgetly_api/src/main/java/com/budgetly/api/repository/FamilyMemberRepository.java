package com.budgetly.api.repository;

import com.budgetly.api.document.FamilyMemberDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FamilyMemberRepository extends MongoRepository<FamilyMemberDocument, String> {
    List<FamilyMemberDocument> findByFamilyGroupId(String familyGroupId);

    /**
     * Active members of a family ordered by join time ascending, so the earliest
     * joiner is at index 0 — used to pick an admin successor.
     */
    List<FamilyMemberDocument> findByFamilyGroupIdAndStatusOrderByJoinedAtAsc(String familyGroupId, String status);
    Optional<FamilyMemberDocument> findByUserIdAndFamilyGroupId(String userId, String familyGroupId);
    List<FamilyMemberDocument> findByUserId(String userId);
    boolean existsByUserIdAndFamilyGroupId(String userId, String familyGroupId);

    /** True only when the user has an ACTIVE membership in the family. */
    boolean existsByUserIdAndFamilyGroupIdAndStatus(String userId, String familyGroupId, String status);
    void deleteAllByFamilyGroupId(String familyGroupId);
}
