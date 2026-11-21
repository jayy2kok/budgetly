package com.budgetly.api.repository;

import com.budgetly.api.document.SmsPatternDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface PatternRegistryRepository extends MongoRepository<SmsPatternDocument, String> {
    List<SmsPatternDocument> findByActiveTrue();
    List<SmsPatternDocument> findByActiveTrueAndCreatedAtAfter(Instant since);
    List<SmsPatternDocument> findBySenderAndActiveTrue(String sender);

    /**
     * Active patterns visible to a family: all GLOBAL patterns plus the
     * family's own FAMILY-scoped patterns.
     */
    @Query("{ 'active': true, $or: [ { 'scope': { $ne: 'FAMILY' } }, { 'ownerFamilyGroupId': ?0 } ] }")
    List<SmsPatternDocument> findActiveGlobalOrFamily(String familyGroupId);

    /** Delta-sync variant of {@link #findActiveGlobalOrFamily(String)}. */
    @Query("{ 'active': true, 'createdAt': { $gt: ?1 }, $or: [ { 'scope': { $ne: 'FAMILY' } }, { 'ownerFamilyGroupId': ?0 } ] }")
    List<SmsPatternDocument> findActiveGlobalOrFamilySince(String familyGroupId, Instant since);

    /** Active patterns visible to a family for a specific sender. */
    @Query("{ 'sender': ?0, 'active': true, $or: [ { 'scope': { $ne: 'FAMILY' } }, { 'ownerFamilyGroupId': ?1 } ] }")
    List<SmsPatternDocument> findActiveForSenderAndFamily(String sender, String familyGroupId);

    boolean existsBySenderAndTemplateAndActiveTrue(String sender, String template);
}
