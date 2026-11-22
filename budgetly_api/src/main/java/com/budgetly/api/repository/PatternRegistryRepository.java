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
     * Everything the caller's family may see in the registry: active GLOBAL
     * patterns plus all of the family's own patterns, including disabled ones
     * (the registry lists them with an Enable action).
     */
    @Query("{ $or: [ { 'scope': 'GLOBAL', 'active': true }, { 'ownerFamilyGroupId': ?0 } ] }")
    List<SmsPatternDocument> findVisibleForFamily(String familyGroupId);

    /** Delta-sync variant of {@link #findVisibleForFamily(String)}: created or updated after {@code since}. */
    @Query("{ $and: ["
            + " { $or: [ { 'createdAt': { $gt: ?1 } }, { 'updatedAt': { $gt: ?1 } } ] },"
            + " { $or: [ { 'scope': 'GLOBAL', 'active': true }, { 'ownerFamilyGroupId': ?0 } ] }"
            + " ] }")
    List<SmsPatternDocument> findVisibleForFamilySince(String familyGroupId, Instant since);

    /** Active patterns visible to a family for a specific sender. */
    @Query("{ 'sender': ?0, 'active': true, $or: [ { 'scope': { $ne': 'FAMILY' } }, { 'ownerFamilyGroupId': ?1 } ] }")
    List<SmsPatternDocument> findActiveForSenderAndFamily(String sender, String familyGroupId);

    /** All patterns of a family for a sender+template (any state), used for duplicate/reactivation. */
    List<SmsPatternDocument> findByOwnerFamilyGroupIdAndSenderAndTemplate(
            String ownerFamilyGroupId, String sender, String template);

    /** The family copy created by editing a GLOBAL pattern, if it exists. */
    java.util.Optional<SmsPatternDocument> findByOwnerFamilyGroupIdAndDerivedFromPatternId(
            String ownerFamilyGroupId, String derivedFromPatternId);
}
