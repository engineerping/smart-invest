package com.smartinvest.user.service;

import com.smartinvest.common.security.JwtTokenProvider;
import com.smartinvest.user.domain.User;
import com.smartinvest.user.dto.*;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.*;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

/**
 * 认证服务 —— 注册 & 登录
 * =============================================================================
 * 关键决策：签发的 JWT 里 sub 存 userId（不是 email）。
 * 这样其他微服务拿到 token 直接解析出 userId 就能用于业务，
 * 不必为每个请求都查一次 users 表。这就是"无状态认证"的优势。
 * =============================================================================
 */
@Service @RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final AuthenticationManager authManager;

    public AuthResponse register(RegisterRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw new IllegalArgumentException("Email already registered");
        }
        User user = new User();
        user.setEmail(req.email());
        user.setPassword(passwordEncoder.encode(req.password()));
        user.setFullName(req.fullName());
        user = userRepository.save(user);
        // 签发 token，sub = user.getId()
        return new AuthResponse(tokenProvider.createAccessToken(user.getId().toString()));
    }

    public AuthResponse login(LoginRequest req) {
        authManager.authenticate(new UsernamePasswordAuthenticationToken(req.email(), req.password()));
        User user = userRepository.findByEmail(req.email())
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        return new AuthResponse(tokenProvider.createAccessToken(user.getId().toString()));
    }
}
