package com.budgetly.api.repository;

import com.budgetly.api.document.DeviceTokenDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface DeviceTokenRepository extends MongoRepository<DeviceTokenDocument, String> {

    Optional<DeviceTokenDocument> findByToken(String token);

    List<DeviceTokenDocument> findByUserIdIn(Collection<String> userIds);

    List<DeviceTokenDocument> findByUserId(String userId);
}
