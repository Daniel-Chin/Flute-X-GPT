#include "role.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'

#include "esp_log.h"
#include "driver/mcpwm_prelude.h"

#include "servo.h"
#include "shared.h"
#include "env.h"

static mcpwm_cmpr_handle_t comparators[N_SERVOS] = {};

static inline uint32_t angleToUS(int angle)
{
    return (angle - SERVO_MIN_ANGLE) * (
        SERVO_MAX_US - SERVO_MIN_US
    ) / (SERVO_MAX_ANGLE - SERVO_MIN_ANGLE) + SERVO_MIN_US;
}

static int const GROUP_LOOKUP[3] = {0, 1, 1};
mcpwm_cmpr_handle_t initServo(servo_id_t servo_id) {
    int group_id = GROUP_LOOKUP[servo_id];

    mcpwm_timer_handle_t timer = NULL;
    mcpwm_timer_config_t timer_config = {
        .group_id = group_id,
        .clk_src = MCPWM_TIMER_CLK_SRC_DEFAULT,
        .resolution_hz = SERVO_TIMEBASE_RESOLUTION_HZ,
        .period_ticks = SERVO_TIMEBASE_PERIOD,
        .count_mode = MCPWM_TIMER_COUNT_MODE_UP,
    };
    ESP_ERROR_CHECK(mcpwm_new_timer(&timer_config, &timer));

    mcpwm_oper_handle_t oper = NULL;
    mcpwm_operator_config_t operator_config = {
        .group_id = group_id,
    };
    ESP_ERROR_CHECK(mcpwm_new_operator(&operator_config, &oper));

    ESP_LOGI(PROJECT_TAG, "Connect timer and operator...");
    ESP_ERROR_CHECK(mcpwm_operator_connect_timer(oper, timer));

    ESP_LOGI(PROJECT_TAG, "Create comparator and generator from the operator...");
    mcpwm_cmpr_handle_t comparator = NULL;
    mcpwm_comparator_config_t comparator_config = {
        .flags.update_cmp_on_tez = true,
    };
    ESP_ERROR_CHECK(mcpwm_new_comparator(oper, &comparator_config, &comparator));

    mcpwm_gen_handle_t generator = NULL;
    mcpwm_generator_config_t generator_config = {
        .gen_gpio_num = SERVO_PINS[servo_id],
    };
    ESP_ERROR_CHECK(mcpwm_new_generator(
        oper, &generator_config, &generator
    ));
    
    // set the initial compare value, so that the servo will spin to the center position
    ESP_ERROR_CHECK(mcpwm_comparator_set_compare_value(
        comparator, angleToUS(SERVO_MID_ANGLE)
    ));

    ESP_LOGI(PROJECT_TAG, "Set generator action on timer and compare event");
    for (int i = 0; i < N_SERVOS; i++) {
        // go high on counter empty
        ESP_ERROR_CHECK(mcpwm_generator_set_action_on_timer_event(generator,
                        MCPWM_GEN_TIMER_EVENT_ACTION(MCPWM_TIMER_DIRECTION_UP, MCPWM_TIMER_EVENT_EMPTY, MCPWM_GEN_ACTION_HIGH)));
        // go low on compare threshold
        ESP_ERROR_CHECK(mcpwm_generator_set_action_on_compare_event(generator,
                        MCPWM_GEN_COMPARE_EVENT_ACTION(MCPWM_TIMER_DIRECTION_UP, comparator, MCPWM_GEN_ACTION_LOW)));
    }

    ESP_LOGI(PROJECT_TAG, "Enable and start timer");
    ESP_ERROR_CHECK(mcpwm_timer_enable(timer));
    ESP_ERROR_CHECK(mcpwm_timer_start_stop(timer, MCPWM_TIMER_START_NO_STOP));    

    return comparator;
}

void initServos(void) {
    ESP_LOGI(PROJECT_TAG, "initServos()...");

    for (int i = 0; i < N_SERVOS; i++) {
        comparators[i] = initServo(i);
    }

    ESP_LOGI(PROJECT_TAG, "initServos() ok");
}

void moveServo(servo_id_t id, int angle) {
    ESP_ERROR_CHECK(mcpwm_comparator_set_compare_value(
        comparators[id], angleToUS(angle)
    ));
}

#endif
