package com.smartinvest.fund.repository;

import com.smartinvest.fund.domain.FundNavHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface FundNavHistoryRepository extends JpaRepository<FundNavHistory, Long> {
    List<FundNavHistory> findByFundIdAndNavDateAfterOrderByNavDateAsc(UUID fundId, LocalDate after);
    Optional<FundNavHistory> findTopByFundIdOrderByNavDateDesc(UUID fundId);
    Optional<FundNavHistory> findTopByFundIdAndNavDateLessThanEqualOrderByNavDateDesc(UUID fundId, LocalDate asOf);
}
