package com.smartinvest.order.repository;

import com.smartinvest.order.domain.Order;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface OrderRepository extends JpaRepository<Order, UUID> {
    Page<Order> findByUserIdOrderByOrderDateDesc(UUID userId, Pageable pageable);
    List<Order> findByUserIdAndStatus(UUID userId, String status);
    List<Order> findByStatusAndSettlementDateLessThanEqual(String status, LocalDate date);
}