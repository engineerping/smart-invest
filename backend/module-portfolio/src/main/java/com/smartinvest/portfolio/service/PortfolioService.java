package com.smartinvest.portfolio.service;

import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.repository.HoldingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.*;

@Service @RequiredArgsConstructor
public class PortfolioService {
    private final HoldingRepository holdingRepository;

    public List<Holding> getHoldings(UUID userId) {
        return holdingRepository.findByUserId(userId);
    }
}
