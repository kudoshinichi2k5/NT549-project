# ========== COMPREHENSIVE RL TRAINING LOGGING ==========
# Add this cell AFTER training and evaluation to log all metrics

from rl_training_logger import RLTrainingLogger, RLTrainingAnalyzer

# Initialize logger
logger = RLTrainingLogger('./training_results')

# Create new run with timestamp
run_dir = logger.create_run()
print(f"✓ Created run directory: {run_dir}\n")

# ========== LOG ENVIRONMENT CONFIG ==========
logger.log_environment_config({
    'max_steps': env_config['max_steps'],
    'observation_step_interval': env_config.get('step_interval_sec', 10),
    'num_deployments': env_config['num_deployments'],
    'num_nodes': env_config['num_nodes'],
})

# ========== LOG TRAINING HYPERPARAMETERS ==========
logger.log_training_config({
    'algorithm': training_config['algorithm'],
    'total_timesteps': training_config['total_timesteps'],
    'learning_rate': training_config['learning_rate'],
    'n_steps': training_config['n_steps'],
    'batch_size': training_config['batch_size'],
    'gamma': training_config['gamma'],
    'gae_lambda': training_config['gae_lambda'],
    'ent_coef': training_config.get('ent_coef', 0.0),
    'clip_range': training_config.get('clip_range', 0.2),
})

# ========== LOG REWARD WEIGHTS ==========
logger.log_reward_weights({
    'alpha': RewardCalculator.ALPHA,
    'beta': RewardCalculator.BETA,
    'gamma': RewardCalculator.GAMMA,
    'delta': RewardCalculator.DELTA,
    'epsilon': RewardCalculator.EPSILON if hasattr(RewardCalculator, 'EPSILON') else None,
    'step_penalty': RewardCalculator.STEP_PENALTY,
    'recovery_bonus': RewardCalculator.RECOVERY_BONUS,
    'collapse_penalty': RewardCalculator.COLLAPSE_PENALTY,
})

# ========== LOG STATE & ACTION SPACE ==========
logger.log_state_action_space(
    state_info={
        'continuous_dims': len(StateSpace.CONTINUOUS_METRICS),
        'discrete_dims': len(StateSpace.DISCRETE_METRICS),
        'total_observation_shape': 12,
        'continuous_metrics': list(StateSpace.CONTINUOUS_METRICS.keys()),
        'discrete_metrics': list(StateSpace.DISCRETE_METRICS.keys()),
    },
    action_info={
        'total_actions': len(ActionSpace.ACTIONS),
        'actions': {str(k): v['name'] for k, v in ActionSpace.ACTIONS.items()},
        'action_space_type': 'Discrete',
    }
)

# ========== LOG EVALUATION METRICS ==========
# Trained agent
logger.log_evaluation_metrics({
    'success_rate': eval_metrics['success_rate'],
    'avg_recovery_steps': eval_metrics['avg_recovery_steps'],
    'avg_reward': eval_metrics['avg_reward'],
    'std_reward': eval_metrics['std_reward'],
}, agent_type='trained')

# Baseline agent
logger.log_evaluation_metrics({
    'success_rate': baseline_metrics['success_rate'],
    'avg_recovery_steps': baseline_metrics['avg_recovery_steps'],
    'avg_reward': baseline_metrics['avg_reward'],
    'std_reward': baseline_metrics['std_reward'],
}, agent_type='baseline')

# ========== CALCULATE IMPROVEMENTS ==========
logger.calculate_improvement()

# ========== SAVE COMPREHENSIVE LOG ==========
log_file = logger.save()
print(f"✓ Comprehensive log saved: {log_file}\n")

# ========== PRINT SUMMARY ==========
RLTrainingAnalyzer.print_run_summary(logger.get_summary())

# ========== SAVE COMPARISON ACROSS RUNS ==========
comparison_df = RLTrainingLogger.create_comparison_df('./training_results')
comparison_df.to_csv('./training_results/runs_comparison.csv', index=False)
print(f"✓ Comparison saved: ./training_results/runs_comparison.csv\n")

# Print all runs comparison
if len(comparison_df) > 0:
    print("📊 ALL TRAINING RUNS:")
    RLTrainingAnalyzer.compare_runs(comparison_df)
    
    # Show best run
    best_by_success = RLTrainingAnalyzer.get_best_run(comparison_df, 'success_rate')
    print(f"\n🏆 BEST BY SUCCESS RATE: {best_by_success['run_name']} ({best_by_success['success_rate']:.1%})")
