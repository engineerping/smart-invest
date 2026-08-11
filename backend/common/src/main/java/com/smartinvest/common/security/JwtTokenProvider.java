package com.smartinvest.common.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 令牌工具 —— 所有微服务共用
 * =============================================================================
 * 负责签发和校验 JWT。关键设计决策：
 *   1. sub（subject）存的是【userId】，而不是 email。
 *      因为其他服务（order/fund）只关心"这是哪个用户"，不关心用户邮箱。
 *      这样 order-service 拿到的 principal.getUsername() 就是 userId，可直接用于业务。
 *   2. 所有服务用同一个 jwt.secret，所以任何一个服务都能校验其他服务签发的令牌
 *      （无状态认证：不需要每个服务都查数据库确认用户）。
 * =============================================================================
 */
@Component
public class JwtTokenProvider {

    private final SecretKey key;
    private final long accessTokenExpiryMs;

    public JwtTokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-token-expiry-ms}") long accessTokenExpiryMs) {
        // HMAC-SHA 需要密钥至少 256 bit（32 字节），过短会抛异常
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiryMs = accessTokenExpiryMs;
    }

    /** 为用户签发 access token，sub = userId */
    public String createAccessToken(String userId) {
        Date now = new Date();
        return Jwts.builder()
                .subject(userId)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + accessTokenExpiryMs))
                .signWith(key)
                .compact();
    }

    /** 从 token 解析出 userId（即 sub） */
    public String getUserIdFromToken(String token) {
        return Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload().getSubject();
    }

    /** 校验 token 是否合法（签名 + 过期时间） */
    public boolean validateToken(String token) {
        try {
            Jwts.parser().verifyWith(key).build().parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
}
