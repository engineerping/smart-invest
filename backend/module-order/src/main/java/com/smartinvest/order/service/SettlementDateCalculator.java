package com.smartinvest.order.service;

import org.springframework.stereotype.Component;
import java.time.*;

@Component
public class SettlementDateCalculator {

    /**
     * Calculate settlement date by counting business days forward.
     * Skips weekends (Saturday and Sunday).
     */
    public LocalDate calculate(LocalDate from, int businessDays) {
        LocalDate date = from;
        int count = 0;
        while (count < businessDays) {
            date = date.plusDays(1);
            DayOfWeek dow = date.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) {
                count++;
            }
        }
        return date;
    }
}