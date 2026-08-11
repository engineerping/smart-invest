package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundAssetAllocation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundAssetAllocationRepository extends JpaRepository<FundAssetAllocation, UUID> {
    List<FundAssetAllocation> findByFundIdOrderByAssetClass(UUID fundId);
}