package com.smartinvest.common.event;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * RabbitMQ 公共配置 —— order/fund/notification 三个服务共用
 * =============================================================================
 * 定义一组固定的 exchange / queue / binding，三个服务用同一套"广播协议"：
 *
 *   交换机： smart-invest.exchange   (direct 类型)
 *     路由键   order.settlement     → 队列 smart-invest.order.settlement   （fund-service 消费，更新持仓）
 *     路由键   order.notification   → 队列 smart-invest.order.notification （notification-worker 消费，写通知）
 *
 * 为什么用 direct 而不是 topic？
 *   - 我们现在只有两种事件，direct 简单直观，面试讲得清楚。
 *   - 将来事件变多可以平滑升级到 topic（通配符 # *），代码不用大改。
 *
 * 消息体用 JSON：Jackson2JsonMessageConverter 自动把 Java 对象序列化成 JSON，
 * 消费者收到后自动反序列化成 OrderEvent 对象。
 * =============================================================================
 */
@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE = "smart-invest.exchange";

    public static final String SETTLEMENT_QUEUE = "smart-invest.order.settlement";
    public static final String SETTLEMENT_ROUTING_KEY = "order.settlement";

    public static final String NOTIFICATION_QUEUE = "smart-invest.order.notification";
    public static final String NOTIFICATION_ROUTING_KEY = "order.notification";

    @Bean
    public DirectExchange orderExchange() {
        return new DirectExchange(EXCHANGE, true, false); // durable 持久化交换机
    }

    @Bean
    public Queue settlementQueue() {
        return new Queue(SETTLEMENT_QUEUE, true); // durable 持久化队列，RabbitMQ 重启不丢
    }

    @Bean
    public Queue notificationQueue() {
        return new Queue(NOTIFICATION_QUEUE, true);
    }

    @Bean
    public Binding settlementBinding(Queue settlementQueue, DirectExchange orderExchange) {
        return BindingBuilder.bind(settlementQueue).to(orderExchange).with(SETTLEMENT_ROUTING_KEY);
    }

    @Bean
    public Binding notificationBinding(Queue notificationQueue, DirectExchange orderExchange) {
        return BindingBuilder.bind(notificationQueue).to(orderExchange).with(NOTIFICATION_ROUTING_KEY);
    }

    /**
     * 让 RabbitTemplate 用 JSON 序列化消息体。
     * 这样生产/消费两端看到的都是可读的 JSON，方便在 RabbitMQ 管理台调试。
     */
    @Bean
    public Jackson2JsonMessageConverter jacksonConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory,
                                        Jackson2JsonMessageConverter converter) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(converter);
        return template;
    }
}
