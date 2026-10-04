package com.budgetly.api.repository;

import com.budgetly.api.document.ChangeStreamTokenDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ChangeStreamTokenRepository extends MongoRepository<ChangeStreamTokenDocument, String> {
}
