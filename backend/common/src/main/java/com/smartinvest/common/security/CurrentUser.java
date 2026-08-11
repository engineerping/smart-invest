package com.smartinvest.common.security;

/**
 * 当前登录用户 ID 工具 —— 从 SecurityContext 里取当前请求的 userId
 * =============================================================================
 * 因为 JwtAuthenticationFilter 把 userId 放进了 principal.getUsername()，
 * controller 里可以用 @AuthenticationPrincipal UserDetails principal 拿到，
 * 但每次都要写 UUID.fromString(principal.getUsername()) 很啰嗦，
 * 所以提供这个静态方法，一行拿到当前用户 ID。
 * =============================================================================
 */
public final class CurrentUser {

    private CurrentUser() {}

    /** 取当前请求的用户 ID；未认证时返回 null */
    public static String id() {
        var auth = org.springframework.security.core.context.SecurityContextHolder
                .getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return null;
        }
        return auth.getName(); // JwtAuthenticationFilter 已把 userId 设为 principal 的 username
    }
}
