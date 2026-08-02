package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundTopHolding;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface FundTopHoldingRepository extends JpaRepository<FundTopHolding, UUID> {
    List<FundTopHolding> findByFundIdOrderBySequence(UUID fundId);
}
