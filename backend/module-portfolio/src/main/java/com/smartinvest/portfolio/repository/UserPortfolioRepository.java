package com.smartinvest.portfolio.repository;

import com.smartinvest.portfolio.domain.UserPortfolio;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface UserPortfolioRepository extends JpaRepository<UserPortfolio, UUID> {
    List<UserPortfolio> findByUserIdAndStatus(UUID userId, String status);
}
