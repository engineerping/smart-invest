package com.smartinvest.portfolio.repository;

import com.smartinvest.portfolio.domain.Holding;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface HoldingRepository extends JpaRepository<Holding, UUID> {
    List<Holding> findByUserId(UUID userId);
    Optional<Holding> findByUserIdAndFundId(UUID userId, UUID fundId);
}
