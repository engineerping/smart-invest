package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundGeoAllocation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundGeoAllocationRepository extends JpaRepository<FundGeoAllocation, UUID> {
    List<FundGeoAllocation> findByFundIdOrderByRegion(UUID fundId);
}
