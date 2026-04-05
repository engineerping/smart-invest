package com.smartinvest.user.service;

import com.smartinvest.user.domain.User;
import com.smartinvest.user.dto.UserResponse;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;

    public UserResponse getCurrentUser(String email) {
        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        return new UserResponse(user.getId(), user.getEmail(), user.getFullName(),
                               user.getRiskLevel(), user.getStatus());
    }
}