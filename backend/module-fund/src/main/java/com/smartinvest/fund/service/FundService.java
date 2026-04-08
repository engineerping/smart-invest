package com.smartinvest.fund.service;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.*;

@Service @RequiredArgsConstructor
public class FundService {
    private final FundRepository fundRepository;
    private final FundNavHistoryRepository navHistoryRepository;
    private final FundAssetAllocationRepository assetAllocationRepository;
    private final FundTopHoldingRepository topHoldingRepository;
    private final FundSectorAllocationRepository sectorAllocationRepository;
    private final FundGeoAllocationRepository geoAllocationRepository;

    public List<Fund> getAllFunds(String type, Short riskLevel) {
        List<Fund> funds;
        if (type != null) {
            funds = fundRepository.findByFundTypeAndIsActiveTrue(type);
        } else {
            funds = fundRepository.findByIsActiveTrue();
        }
        if (riskLevel != null) {
            funds = funds.stream().filter(f -> f.getRiskLevel() == riskLevel).toList();
        }
        return funds;
    }

    public Fund getFundById(UUID id) {
        return fundRepository.findById(id)
            .orElseThrow(() -> new NoSuchElementException("Fund not found: " + id));
    }

    public List<Fund> getMultiAssetFunds() {
        return fundRepository.findByFundTypeAndIsActiveTrue("MULTI_ASSET");
    }

    public List<FundNavHistory> getNavHistory(UUID fundId, String period) {
        LocalDate from = switch (period) {
            case "6M" -> LocalDate.now().minusMonths(6);
            case "1Y" -> LocalDate.now().minusYears(1);
            case "3Y" -> LocalDate.now().minusYears(3);
            case "5Y" -> LocalDate.now().minusYears(5);
            default   -> LocalDate.now().minusMonths(3); // 3M
        };
        return navHistoryRepository.findByFundIdAndNavDateAfterOrderByNavDateAsc(fundId, from);
    }

    public List<FundAssetAllocation> getAssetAllocation(UUID fundId) {
        return assetAllocationRepository.findByFundIdOrderByAssetClass(fundId);
    }

    public List<FundTopHolding> getTopHoldings(UUID fundId) {
        return topHoldingRepository.findByFundIdOrderBySequence(fundId);
    }

    public List<FundSectorAllocation> getSectorAllocation(UUID fundId) {
        return sectorAllocationRepository.findByFundIdOrderBySector(fundId);
    }

    public List<FundGeoAllocation> getGeoAllocation(UUID fundId) {
        return geoAllocationRepository.findByFundIdOrderByRegion(fundId);
    }
}