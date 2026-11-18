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
import com.budgetly.api.repository.TransactionRepository;
import com.budgetly.api.repository.CategoryRepository;
import com.budgetly.api.repository.MessageRepository;
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
    private final CategoryService categoryService;
    private final UserRepository userRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final MessageRepository messageRepository;

    public FamilyGroup createFamily(String userId, CreateFamilyRequest request) {
        FamilyGroupDocument group = FamilyGroupDocument.builder()
                .name(request.getName())
                .avatarInitial(request.getAvatarInitial() != null ? request.getAvatarInitial()
                        : request.getName().substring(0, 1).toUpperCase())
                .defaultCurrency(request.getDefaultCurrency() != null ? request.getDefaultCurrency() : "INR")
                .monthlyBudgetLimit(request.getMonthlyBudgetLimit() != null ? request.getMonthlyBudgetLimit() : 0.0)
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

        // Give the new family a starter set of categories so the Budget and
        // Add Expense screens are usable immediately.
        categoryService.seedDefaultCategories(group.getId());

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

        // The caller is leaving their own family. Detach by membership lookup,
        // not by member document id (deleteFamily receives a userId, not an id).
        FamilyMemberDocument ownMembership = familyMemberRepository
                .findByUserIdAndFamilyGroupId(userId, familyId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyMember", userId));
        detachMember(ownMembership);
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
        FamilyGroupDocument group = familyGroupRepository.findById(familyId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyGroup", familyId));

        return doJoin(userId, group, request);
    }

    /**
     * Resolves the family from the invite code alone, then joins it.
     * Used by {@code POST /families/join} so QR / deep-link clients that only
     * hold a code do not need to know the family id up front.
     */
    public FamilyMember joinFamilyByCode(String userId, JoinFamilyRequest request) {
        String inviteCode = request == null ? null : request.getInviteCode();
        if (inviteCode == null || inviteCode.isBlank()) {
            throw new IllegalArgumentException("Invite code is required");
        }

        FamilyGroupDocument group = familyGroupRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new IllegalArgumentException("Invalid invite code"));

        return doJoin(userId, group, request);
    }

    /**
     * Shared join path for both entry points.
     *
     * Ordering matters: every validation runs BEFORE any destructive write, so a
     * bad/expired code or an "already a member" rejection can never destroy the
     * caller's existing family.
     */
    private FamilyMember doJoin(String userId, FamilyGroupDocument group, JoinFamilyRequest request) {
        String familyId = group.getId();

        if (group.getInviteCodeExpiresAt() != null
                && Instant.now().isAfter(group.getInviteCodeExpiresAt())) {
            throw new IllegalArgumentException("Invite code has expired");
        }

        FamilyMemberDocument existing = familyMemberRepository
                .findByUserIdAndFamilyGroupId(userId, familyId)
                .orElse(null);

        // Only an ACTIVE membership blocks a join. A REMOVED row means the user
        // left/was removed before, and must be allowed to re-join.
        if (existing != null && "ACTIVE".equals(existing.getStatus())) {
            throw new IllegalStateException("You are already a member of this family");
        }

        // Validation passed — only now may we leave the user's previous family.
        leaveCurrentFamily(userId, familyId);

        FamilyMemberDocument member;
        if (existing != null) {
            // Re-activate the previous membership in place — the (userId,
            // familyGroupId) pair is uniquely indexed, so we must never insert a
            // duplicate row for a user who was previously a member.
            existing.setStatus("ACTIVE");
            existing.setRole("MEMBER");
            existing.setJoinedAt(Instant.now());
            member = familyMemberRepository.save(existing);
        } else {
            member = familyMemberRepository.save(FamilyMemberDocument.builder()
                    .userId(userId)
                    .familyGroupId(familyId)
                    .role("MEMBER")
                    .status("ACTIVE")
                    .build());
        }
        UserDocument user = userRepository.findById(userId).orElse(null);
        return toMemberDto(member, user);
    }

    /**
     * Detaches the user from their current family (if it is not [targetFamilyId]).
     *
     * A family is only physically deleted once it has no ACTIVE members left.
     * When an admin leaves, the next longest-serving active member is promoted
     * so the family is never left without an administrator.
     */
    private void leaveCurrentFamily(String userId, String targetFamilyId) {
        List<FamilyMemberDocument> memberships = familyMemberRepository.findByUserId(userId);
        java.util.Optional<FamilyMemberDocument> active = memberships.stream()
                .filter(m -> "ACTIVE".equals(m.getStatus()))
                .filter(m -> !m.getFamilyGroupId().equals(targetFamilyId))
                .findFirst();

        if (!active.isPresent()) return;

        detachMember(active.get());
    }

    /**
     * Marks a membership REMOVED and cleans up the family when it empties.
     * Promotes a successor admin when the departing member was an admin.
     */
    private void detachMember(FamilyMemberDocument member) {
        String familyId = member.getFamilyGroupId();

        boolean wasAdmin = "ADMIN".equals(member.getRole());

        member.setStatus("REMOVED");
        familyMemberRepository.save(member);

        if (wasAdmin) {
            promoteNewAdmin(familyId);
        }

        List<FamilyMemberDocument> remaining = familyMemberRepository.findByFamilyGroupId(familyId).stream()
                .filter(m -> "ACTIVE".equals(m.getStatus()))
                .collect(Collectors.toList());

        if (remaining.isEmpty()) {
            purgeFamily(familyId);
        }
    }

    /**
     * Promotes the longest-serving active member to ADMIN.
     * The repository query orders candidates by joinedAt ascending, so the first
     * non-admin row is the earliest joiner; ties break on id for determinism.
     */
    private void promoteNewAdmin(String familyId) {
        List<FamilyMemberDocument> active = familyMemberRepository
                .findByFamilyGroupIdAndStatusOrderByJoinedAtAsc(familyId, "ACTIVE");

        FamilyMemberDocument successor = active.stream()
                .filter(m -> !"ADMIN".equals(m.getRole()))
                .min(java.util.Comparator
                        .comparing(FamilyMemberDocument::getJoinedAt,
                                java.util.Comparator.nullsFirst(java.util.Comparator.naturalOrder()))
                        .thenComparing(FamilyMemberDocument::getId,
                                java.util.Comparator.nullsFirst(java.util.Comparator.naturalOrder())))
                .orElse(null);

        if (successor == null) return;

        successor.setRole("ADMIN");
        familyMemberRepository.save(successor);
        log.info("Promoted member {} to ADMIN of family {}", successor.getUserId(), familyId);
    }

    /**
     * Physically removes a family and every document that belongs to it.
     * Callers must guarantee no ACTIVE members remain.
     */
    private void purgeFamily(String familyId) {
        transactionRepository.deleteAllByFamilyGroupId(familyId);
        categoryRepository.deleteAllByFamilyGroupId(familyId);
        messageRepository.deleteAllByFamilyGroupId(familyId);
        familyMemberRepository.deleteAllByFamilyGroupId(familyId);
        familyGroupRepository.deleteById(familyId);
        log.info("Purged empty family {}", familyId);
    }

    public List<FamilyMember> listMembers(String userId, String familyId) {
        getGroupAndValidateMember(userId, familyId);
        return familyMemberRepository.findByFamilyGroupId(familyId).stream()
                // Only current members are shown; REMOVED rows are kept for the
                // unique (userId, familyGroupId) index but are not "members".
                .filter(m -> "ACTIVE".equals(m.getStatus()))
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

    /**
     * Removes a member from a family.
     *
     * A caller may remove themselves (leaving) or, if an admin, anyone else.
     * When the departing member is an admin the longest-serving active member is
     * promoted to ADMIN. The family is only physically deleted once it has no
     * ACTIVE members left.
     */
    public void removeMember(String userId, String familyId, String memberId) {
        requireAdminRole(userId, familyId);

        FamilyMemberDocument member = familyMemberRepository.findById(memberId)
                .orElseThrow(() -> new ResourceNotFoundException("FamilyMember", memberId));

        if (!member.getFamilyGroupId().equals(familyId)) {
            throw new ForbiddenException("Member does not belong to this family");
        }

        detachMember(member);
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
        boolean isActiveMember = familyMemberRepository
                .existsByUserIdAndFamilyGroupIdAndStatus(userId, familyId, "ACTIVE");
        if (!isActiveMember) throw new ForbiddenException("You are not a member of this family");
        return group;
    }

    private void requireAdminRole(String userId, String familyId) {
        FamilyMemberDocument member = familyMemberRepository
                .findByUserIdAndFamilyGroupId(userId, familyId)
                .orElseThrow(() -> new ForbiddenException("Not a member of this family"));
        if (!"ACTIVE".equals(member.getStatus()) || !"ADMIN".equals(member.getRole())) {
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
