package com.budgetly.api.repository;

import com.budgetly.api.document.SmsPatternDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface PatternRegistryRepository extends MongoRepository<SmsPatternDocument, String> {
    List<SmsPatternDocument> findByActiveTrue();
    List<SmsPatternDocument> findByActiveTrueAndCreatedAtAfter(Instant since);
    List<SmsPatternDocument> findBySenderAndActiveTrue(String sender);
}
