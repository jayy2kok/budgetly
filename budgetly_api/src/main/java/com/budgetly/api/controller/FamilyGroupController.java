package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.FamilyGroupsApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.FamilyGroupService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class FamilyGroupController implements FamilyGroupsApi {

    private final FamilyGroupService familyGroupService;

    @Override
    public ResponseEntity<FamilyGroup> createFamily(CreateFamilyRequest createFamilyRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(familyGroupService.createFamily(userId, createFamilyRequest));
    }

    /** GET /api/v1/families/my — returns (or auto-creates) the authenticated user's family. */
    @Override
    public ResponseEntity<FamilyGroup> getMyFamily() {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.getMyFamily(userId));
    }

    @Override
    public ResponseEntity<FamilyGroup> getFamily(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.getFamily(userId, id));
    }

    @Override
    public ResponseEntity<FamilyGroup> updateFamily(String id, UpdateFamilyRequest updateFamilyRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.updateFamily(userId, id, updateFamilyRequest));
    }

    @Override
    public ResponseEntity<Void> deleteFamily(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        familyGroupService.deleteFamily(userId, id);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<InviteResponse> inviteToFamily(String id, InviteRequest inviteRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.invite(userId, id, inviteRequest));
    }

    @Override
    public ResponseEntity<FamilyMember> joinFamily(String id, JoinFamilyRequest joinFamilyRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.joinFamily(userId, id, joinFamilyRequest));
    }

    @Override
    public ResponseEntity<List<FamilyMember>> listFamilyMembers(String id) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.listMembers(userId, id));
    }

    @Override
    public ResponseEntity<FamilyMember> updateMember(String id, String memberId, UpdateMemberRequest updateMemberRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.updateMember(userId, id, memberId, updateMemberRequest));
    }

    @Override
    public ResponseEntity<Void> removeMember(String id, String memberId) {
        String userId = ControllerUtils.getCurrentUserId();
        familyGroupService.removeMember(userId, id, memberId);
        return ResponseEntity.noContent().build();
    }
}
