package com.budgetly.api.repository;

import com.budgetly.api.document.TransactionDocument;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionRepository extends MongoRepository<TransactionDocument, String> {

    Optional<TransactionDocument> findByIdAndFamilyGroupId(String id, String familyGroupId);

    Page<TransactionDocument> findByFamilyGroupId(String familyGroupId, Pageable pageable);

    @Query("{ 'familyGroupId': ?0, 'type': ?1 }")
    Page<TransactionDocument> findByFamilyGroupIdAndType(String familyGroupId, String type, Pageable pageable);

    @Query("{ 'familyGroupId': ?0, 'transactionDate': { '$gte': ?1, '$lte': ?2 } }")
    Page<TransactionDocument> findByFamilyGroupIdAndDateRange(
            String familyGroupId, Instant startDate, Instant endDate, Pageable pageable);

    @Query("{ 'familyGroupId': ?0, 'transactionDate': { '$gte': ?1, '$lte': ?2 } }")
    List<TransactionDocument> findByFamilyGroupIdAndDateRangeList(
            String familyGroupId, Instant startDate, Instant endDate);

    @Query("{ 'familyGroupId': ?0, 'categoryId': ?1 }")
    Page<TransactionDocument> findByFamilyGroupIdAndCategoryId(
            String familyGroupId, String categoryId, Pageable pageable);

    List<TransactionDocument> findTop5ByFamilyGroupIdOrderByTransactionDateDesc(String familyGroupId);

    void deleteAllByCategoryId(String categoryId);
}
