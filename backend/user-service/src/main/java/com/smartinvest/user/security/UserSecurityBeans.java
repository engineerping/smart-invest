package com.smartinvest.user.security;

import com.smartinvest.user.domain.User;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

/**
 * user-service 专属安全装配
 * =============================================================================
 * 只有 user-service 需要"按邮箱加载完整用户（含密码）"来做登录认证，
 * 所以 PasswordEncoder / UserDetailsService / AuthenticationManager 三个 Bean
 * 放在这里，而不是塞进 common（其他服务用不到，塞进去反而多引入数据库依赖）。
 *
 * 注意：这里提供的 UserDetailsService 是给【登录时校验密码】用的（按 email 查库）。
 *       而 common 的 JwtAuthenticationFilter 校验【已签发的 token】用的是 userId，
 *       两者职责不同，互不干扰。
 * =============================================================================
 */
@Configuration
@RequiredArgsConstructor
public class UserSecurityBeans {

    private final UserRepository userRepository;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> {
            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new UsernameNotFoundException("User not found: " + email));
            // 注意：登录后 principal 是 userId，但这里加载用的是 email（登录输入）。
            // Spring Security 的 DaoAuthenticationProvider 会先按 username 加载再比对密码。
            return new org.springframework.security.core.userdetails.User(
                    user.getId().toString(), user.getPassword(),
                    List.of(new SimpleGrantedAuthority("ROLE_USER")));
        };
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration cfg) throws Exception {
        return cfg.getAuthenticationManager();
    }
}
