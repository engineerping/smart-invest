package com.smartinvest.holding.repository;

import com.smartinvest.holding.domain.Holding;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface HoldingRepository extends JpaRepository<Holding, UUID> {
    List<Holding> findByUserId(UUID userId);
    Optional<Holding> findByUserIdAndFundId(UUID userId, UUID fundId);
}
