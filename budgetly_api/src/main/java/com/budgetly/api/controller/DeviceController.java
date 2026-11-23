package com.budgetly.api.controller;

import com.budgetly.api.generated.controller.DevicesApi;
import com.budgetly.api.generated.model.RegisterDeviceRequest;
import com.budgetly.api.service.DeviceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DeviceController implements DevicesApi {

    private final DeviceService deviceService;

    @Override
    public ResponseEntity<Void> registerDevice(RegisterDeviceRequest registerDeviceRequest) {
        deviceService.register(ControllerUtils.getCurrentUserId(), registerDeviceRequest);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<Void> unregisterDevice(String token) {
        deviceService.unregister(ControllerUtils.getCurrentUserId(), token);
        return ResponseEntity.noContent().build();
    }
}
