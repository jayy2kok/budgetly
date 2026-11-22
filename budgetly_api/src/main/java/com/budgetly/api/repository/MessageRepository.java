package com.budgetly.api.repository;

import com.budgetly.api.document.MessageDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MessageRepository extends MongoRepository<MessageDocument, String> {
    void deleteAllByFamilyGroupId(String familyGroupId);
}