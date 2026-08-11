package com.smartinvest.user.service;

import com.smartinvest.user.domain.User;
import com.smartinvest.user.dto.UserResponse;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.NoSuchElementException;
import java.util.UUID;

/**
 * 用户资料服务
 * 现在 JWT 的 principal 是 userId，所以按 userId 查用户。
 */
@Service @RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;

    public UserResponse getCurrentUser(String userId) {
        User user = userRepository.findById(UUID.fromString(userId))
            .orElseThrow(() -> new NoSuchElementException("User not found"));
        return new UserResponse(user.getId(), user.getEmail(), user.getFullName(),
                               user.getRiskLevel(), user.getStatus());
    }
}
