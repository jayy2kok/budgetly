package com.budgetly.api.repository;

import com.budgetly.api.document.MessageDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MessageRepository extends MongoRepository<MessageDocument, String> {
    List<MessageDocument> findByUserIdAndStatus(String userId, String status);
    List<MessageDocument> findByUserIdAndStatusIn(String userId, List<String> statuses);
    List<MessageDocument> findByFamilyGroupIdAndStatus(String familyGroupId, String status);
    Optional<MessageDocument> findByIdAndUserId(String id, String userId);
    long countByFamilyGroupIdAndStatus(String familyGroupId, String status);
}
