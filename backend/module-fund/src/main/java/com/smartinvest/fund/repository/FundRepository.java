package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.Fund;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundRepository extends JpaRepository<Fund, UUID> {
    List<Fund> findByIsActiveTrue();
    List<Fund> findByFundTypeAndIsActiveTrue(String fundType);
    List<Fund> findByRiskLevelAndIsActiveTrue(short riskLevel);
}