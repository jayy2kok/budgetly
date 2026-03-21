package com.budgetly.api.service;

import com.budgetly.api.document.FamilyGroupDocument;
import com.budgetly.api.document.FamilyMemberDocument;
import com.budgetly.api.document.UserDocument;
import com.budgetly.api.exception.ForbiddenException;
import com.budgetly.api.exception.ResourceNotFoundException;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.repository.FamilyGroupRepository;
import com.budgetly.api.repository.FamilyMemberRepository;
import com.budgetly.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class FamilyGroupService {

    private final FamilyGroupRepository familyGroupRepository;
    private final FamilyMemberRepository familyMemberRepository;
    private final UserRepository userRepository;

    public FamilyGroup createFamily(String userId, CreateFamilyRequest request) {
        FamilyGroupDocument group = FamilyGroupDocument.builder()
                .name(request.getName())
                .avatarInitial(request.getAvatarInitial() != null ? request.getAvatarInitial()
                        : request.getName().substring(0, 1).toUpperCase())
                .defaultCurrency(request.getDefaultCurrency() != null ? request.getDefaultCurrency() : "INR")
                .monthlyBudgetLimit(request.getMonthlyBudgetLimit() != null ? request.getMonthlyBudgetLimit() : 50000.0)
                .createdByUserId(userId)
                .build();
        group = familyGroupRepository.save(group);

        // Creator is automatically an ADMIN member
        FamilyMemberDocument member = FamilyMemberDocument.builder()
                .userId(userId)
                .familyGroupId(group.getId())
                .role("ADMIN")
                .status("ACTIVE")
                .build();
        familyMemberRepository.save(member);

        return toDto(group);
    }

    /**
     * Returns the user's current family, or auto-creates one on first login.
     * A user can only belong to ONE family at a time.
     */
    public FamilyGroup getMyFamily(String userId) {
        List<FamilyMemberDocument> memberships = familyMemberRepository.findByUserId(userId);
        java.util.Optional<FamilyMemberDocument> activeMembership = memberships.stream()
                .filter(m -> "ACTIVE".equals(m.getStatus()))
                .findFirst();

        if (activeMembership.isPresent()) {
            return toDto(familyGroupRepository.findById(activeMembership.get().getFamilyGroupId())
                    .orElseThrow(() -> new ResourceNotFoundException("FamilyGroup",
                            activeMembership.get().getFamilyGroupId())));
        }

        // No family yet — auto-create a personal family for this user
        UserDocument user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));
        String familyName = user.getDisplayName() + "'s Family";

        CreateFamilyRequest req = new CreateFamilyRequest();
        req.setName(familyName);
        req.setDefaultCurrency("INR");
        req.setMonthlyBudgetLimit(50000.0);
        return createFamily(userId, req);
    }

    public FamilyGroup getFamily(String userId, String familyId) {
        FamilyGroupDocument group = getGroupAndValidateMember(userId, familyId);
        return toDto(group);
    }


    public FamilyGroup updateFamily(String userId, String familyId, UpdateFamilyRequest request) {
        FamilyGroupDocument group = getGroupAndValidateMember(userId, familyId);
        requireAdminRole(userId, familyId);

        if (request.getName() != null) group.setName(request.getName());
        if (request.getAvatarInitial() != null) group.setAvatarInitial(request.getAvatarInitial());
        if (request.getDefaultCurrency() != null) group.setDefaultCurrency(request.getDefaultCurrency());
        if (request.getRegionFormat() != null) group.setRegionFormat(request.getRegionFormat());
        if (request.getExpenseAlertsEnabled() != null) group.setExpenseAlertsEnabled(request.getExpenseAlertsEnabled());
        if (request.getMonthlyBudgetLimit() != null) group.setMonthlyBudgetLimit(request.getMonthlyBudgetLimit());

        return toDto(familyGroupRepository.save(group));
    }

    public void deleteFamily(String userId, String familyId) {
        getGroupAndValidateMember(userId, familyId);
        requireAdminRole(userId, familyId);
        familyGroupRepository.deleteById(familyId);
        familyMemberRepository.findByFamilyGroupId(familyId).forEach(m -> familyMemberRepository.delete(m));
    }

    public InviteResponse invite(String userId, String familyId, InviteRequest request) {
        getGroupAndValidateMember(userId, familyId);
        requireAdminRole(userId, familyId);

        String inviteCode = UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
        Instant expiresAt = Instant.now().plusSeconds(7 * 24 * 3600); // 7 days

        FamilyGroupDocument group = familyGroupRepository.findById(familyId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyGroup", familyId));
        group.setInviteCode(inviteCode);
        group.setInviteCodeExpiresAt(expiresAt);
        familyGroupRepository.save(group);

        InviteResponse response = new InviteResponse();
        response.setInviteCode(inviteCode);
        try {
            response.setInviteLink(java.net.URI.create("https://budgetly.app/join?code=" + inviteCode));
        } catch (Exception ignored) { /* fallback: model may have String */ }
        response.setExpiresAt(expiresAt.atOffset(ZoneOffset.UTC));
        return response;
    }

    public FamilyMember joinFamily(String userId, String familyId, JoinFamilyRequest request) {
        FamilyGroupDocument group = familyGroupRepository.findByInviteCode(request.getInviteCode())
                .orElseThrow(() -> new IllegalArgumentException("Invalid invite code"));

        if (!group.getId().equals(familyId)) {
            throw new IllegalArgumentException("Invite code does not match this family");
        }
        if (group.getInviteCodeExpiresAt() != null && Instant.now().isAfter(group.getInviteCodeExpiresAt())) {
            throw new IllegalArgumentException("Invite code has expired");
        }
        if (familyMemberRepository.existsByUserIdAndFamilyGroupId(userId, familyId)) {
            throw new IllegalStateException("You are already a member of this family");
        }

        FamilyMemberDocument member = FamilyMemberDocument.builder()
                .userId(userId)
                .familyGroupId(familyId)
                .role("MEMBER")
                .status("ACTIVE")
                .build();
        member = familyMemberRepository.save(member);
        UserDocument user = userRepository.findById(userId).orElse(null);
        return toMemberDto(member, user);
    }

    public List<FamilyMember> listMembers(String userId, String familyId) {
        getGroupAndValidateMember(userId, familyId);
        return familyMemberRepository.findByFamilyGroupId(familyId).stream()
                .map(m -> {
                    UserDocument user = userRepository.findById(m.getUserId()).orElse(null);
                    return toMemberDto(m, user);
                })
                .collect(Collectors.toList());
    }

    public FamilyMember updateMember(String userId, String familyId, String memberId, UpdateMemberRequest request) {
        requireAdminRole(userId, familyId);
        FamilyMemberDocument member = familyMemberRepository.findById(memberId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyMember", memberId));
        if (request.getRole() != null) {
            member.setRole(request.getRole().getValue());
        }
        member = familyMemberRepository.save(member);
        UserDocument user = userRepository.findById(member.getUserId()).orElse(null);
        return toMemberDto(member, user);
    }

    public void removeMember(String userId, String familyId, String memberId) {
        requireAdminRole(userId, familyId);
        FamilyMemberDocument member = familyMemberRepository.findById(memberId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyMember", memberId));
        member.setStatus("REMOVED");
        familyMemberRepository.save(member);
    }

    public FamilyGroup updateBudget(String userId, String familyId, UpdateBudgetRequest request) {
        FamilyGroupDocument group = getGroupAndValidateMember(userId, familyId);
        requireAdminRole(userId, familyId);
        group.setMonthlyBudgetLimit(request.getMonthlyBudgetLimit());
        return toDto(familyGroupRepository.save(group));
    }

    // ── Helpers ──────────────────────────────────────────────────

    private FamilyGroupDocument getGroupAndValidateMember(String userId, String familyId) {
        FamilyGroupDocument group = familyGroupRepository.findById(familyId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyGroup", familyId));
        boolean isMember = familyMemberRepository.existsByUserIdAndFamilyGroupId(userId, familyId);
        if (!isMember) throw new ForbiddenException("You are not a member of this family");
        return group;
    }

    private void requireAdminRole(String userId, String familyId) {
        FamilyMemberDocument member = familyMemberRepository
                .findByUserIdAndFamilyGroupId(userId, familyId)
                .orElseThrow(() -> new ForbiddenException("Not a member of this family"));
        if (!"ADMIN".equals(member.getRole())) {
            throw new ForbiddenException("Admin role required for this action");
        }
    }

    private FamilyGroup toDto(FamilyGroupDocument doc) {
        FamilyGroup dto = new FamilyGroup();
        dto.setId(doc.getId());
        dto.setName(doc.getName());
        dto.setAvatarInitial(doc.getAvatarInitial());
        dto.setDefaultCurrency(doc.getDefaultCurrency());
        dto.setRegionFormat(doc.getRegionFormat());
        dto.setExpenseAlertsEnabled(doc.isExpenseAlertsEnabled());
        dto.setMonthlyBudgetLimit(doc.getMonthlyBudgetLimit());
        dto.setCreatedByUserId(doc.getCreatedByUserId());
        if (doc.getCreatedAt() != null) dto.setCreatedAt(doc.getCreatedAt().atOffset(ZoneOffset.UTC));
        return dto;
    }

    public static FamilyMember toMemberDto(FamilyMemberDocument doc, UserDocument user) {
        FamilyMember dto = new FamilyMember();
        dto.setId(doc.getId());
        dto.setUserId(doc.getUserId());
        dto.setFamilyGroupId(doc.getFamilyGroupId());
        dto.setRole(MemberRole.fromValue(doc.getRole()));
        dto.setStatus(MemberStatus.fromValue(doc.getStatus()));
        if (doc.getJoinedAt() != null) dto.setJoinedAt(doc.getJoinedAt().atOffset(ZoneOffset.UTC));
        if (user != null) dto.setUser(AuthService.toUserDto(user));
        return dto;
    }
}
