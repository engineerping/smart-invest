package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundSectorAllocation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundSectorAllocationRepository extends JpaRepository<FundSectorAllocation, UUID> {
    List<FundSectorAllocation> findByFundIdOrderBySector(UUID fundId);
}
