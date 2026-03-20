package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.DashboardApi;
import com.budgetly.api.generated.model.*;
import com.budgetly.api.service.DashboardService;
import com.budgetly.api.service.FamilyGroupService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DashboardController implements DashboardApi {

    private final DashboardService dashboardService;
    private final FamilyGroupService familyGroupService;

    @Override
    public ResponseEntity<DashboardData> getDashboard(String fid, String month) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(dashboardService.getDashboard(userId, fid, month));
    }

    @Override
    public ResponseEntity<BudgetSummary> getBudgetSummary(String fid, String month) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(dashboardService.getBudgetSummary(userId, fid, month));
    }

    @Override
    public ResponseEntity<FamilyGroup> updateBudget(String fid, UpdateBudgetRequest updateBudgetRequest) {
        String userId = ControllerUtils.getCurrentUserId();
        return ResponseEntity.ok(familyGroupService.updateBudget(userId, fid, updateBudgetRequest));
    }
}
