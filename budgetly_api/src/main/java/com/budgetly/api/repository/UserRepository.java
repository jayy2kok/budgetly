package com.budgetly.api.repository;

import com.budgetly.api.document.UserDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends MongoRepository<UserDocument, String> {
    Optional<UserDocument> findByGoogleId(String googleId);
    Optional<UserDocument> findByEmail(String email);
}
