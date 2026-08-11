package com.smartinvest.common.security;

import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * JWT 认证过滤器 —— 所有微服务共用
 * =============================================================================
 * 每个 HTTP 请求进来先经过这里：
 *   1. 从 Authorization: Bearer <token> 头里取 token
 *   2. 校验签名/过期（用共享的 jwt.secret，无状态）
 *   3. 把 userId 放进 SecurityContext，后续 @AuthenticationPrincipal 就能拿到
 * 注意：这里不查数据库加载完整用户信息，只用 token 里的 userId，
 *      因为各服务只关心"你是谁"，密码/角色这些只在 user-service 里有意义。
 * =============================================================================
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider tokenProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                if (tokenProvider.validateToken(token)) {
                    String userId = tokenProvider.getUserIdFromToken(token);
                    // 构造一个只有 userId 的最小 UserDetails，主键即 userId
                    UserDetails principal = User.builder()
                            .username(userId)
                            .password("")
                            .authorities(List.of(() -> "ROLE_USER"))
                            .build();
                    var auth = new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
                    SecurityContextHolder.getContext().setAuthentication(auth);
                }
            } catch (JwtException | IllegalArgumentException e) {
                // token 无效则当作未认证，交给后面的 Security 规则决定是否 401
            }
        }
        chain.doFilter(request, response);
    }
}
