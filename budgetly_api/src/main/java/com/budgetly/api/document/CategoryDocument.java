package com.budgetly.api.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "categories")
public class CategoryDocument {

    @Id
    private String id;

    @Indexed
    private String familyGroupId;

    private String name;
    private String icon;
    private double budgetLimit;
    private String color;

    @Builder.Default
    private int sortOrder = 0;
}
