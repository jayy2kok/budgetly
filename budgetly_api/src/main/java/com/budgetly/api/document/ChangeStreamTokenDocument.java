package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "change_stream_tokens")
public class ChangeStreamTokenDocument {

    @Id
    private String id; // "message-processor"

    private String token; // base64 resume token

    @Builder.Default
    private Instant updatedAt = Instant.now();
    
}
