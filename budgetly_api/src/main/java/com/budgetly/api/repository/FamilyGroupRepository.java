package com.budgetly.api.repository;

import com.budgetly.api.document.FamilyGroupDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface FamilyGroupRepository extends MongoRepository<FamilyGroupDocument, String> {
    Optional<FamilyGroupDocument> findByInviteCode(String inviteCode);
}
