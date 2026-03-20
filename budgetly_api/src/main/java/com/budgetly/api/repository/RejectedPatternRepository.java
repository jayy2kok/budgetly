package com.budgetly.api.repository;

import com.budgetly.api.document.RejectedPatternDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RejectedPatternRepository extends MongoRepository<RejectedPatternDocument, String> {
    Optional<RejectedPatternDocument> findByPatternId(String patternId);
}
