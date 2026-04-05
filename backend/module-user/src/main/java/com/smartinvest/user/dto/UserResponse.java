package com.smartinvest.user.dto;

public record UserResponse(java.util.UUID id, String email, String fullName, Short riskLevel, String status) {}