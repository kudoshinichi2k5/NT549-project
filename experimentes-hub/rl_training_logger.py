"""
Comprehensive RL Training Logger
Logs all training parameters, hyperparameters, and evaluation metrics into a single file
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List
import pandas as pd
import numpy as np


class RLTrainingLogger:
    """
    Logs training runs with comprehensive metadata.
    
    Features:
    - Single JSON file per run with all parameters
    - CSV summary for easy comparison across runs
    - Hierarchical tracking (training config, reward config, evaluation results)
    - Automatic timestamping and versioning
    """
    
    def __init__(self, results_dir: str = './training_results'):
        """Initialize logger."""
        self.results_dir = results_dir
        self.run_dir = None
        self.run_name = None
        self.run_data = {}
        
        # Create results directory if not exists
        Path(results_dir).mkdir(parents=True, exist_ok=True)
    
    def create_run(self, run_name: str = None) -> str:
        """
        Create new training run with timestamp.
        
        Args:
            run_name: Optional custom name, else uses timestamp
            
        Returns:
            Path to run directory
        """
        if run_name is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            run_name = f'run_{timestamp}'
        
        self.run_name = run_name
        self.run_dir = os.path.join(self.results_dir, run_name)
        Path(self.run_dir).mkdir(parents=True, exist_ok=True)
        
        # Initialize run data structure
        self.run_data = {
            'timestamp': datetime.now().isoformat(),
            'run_name': run_name,
            'environment_config': {},
            'training_config': {},
            'reward_weights': {},
            'state_space': {},
            'action_space': {},
            'evaluation_metrics': {},
            'baseline_metrics': {},
            'improvement_metrics': {},
        }
        
        return self.run_dir
    
    def log_environment_config(self, config: Dict[str, Any]) -> None:
        """Log environment configuration."""
        self.run_data['environment_config'] = config
    
    def log_training_config(self, config: Dict[str, Any]) -> None:
        """Log training hyperparameters."""
        self.run_data['training_config'] = {
            'algorithm': config.get('algorithm'),
            'total_timesteps': config.get('total_timesteps'),
            'learning_rate': config.get('learning_rate'),
            'n_steps': config.get('n_steps'),
            'batch_size': config.get('batch_size'),
            'gamma': config.get('gamma'),
            'gae_lambda': config.get('gae_lambda'),
            'ent_coef': config.get('ent_coef', 0.0),
            'clip_range': config.get('clip_range', 0.2),
        }
    
    def log_reward_weights(self, weights: Dict[str, float]) -> None:
        """Log reward function weights."""
        self.run_data['reward_weights'] = {
            'alpha_stability': weights.get('alpha', None),
            'beta_overhead': weights.get('beta', None),
            'gamma_disruption': weights.get('gamma', None),
            'delta_sla': weights.get('delta', None),
            'epsilon_efficiency': weights.get('epsilon', None),
            'step_penalty': weights.get('step_penalty', None),
            'recovery_bonus': weights.get('recovery_bonus', None),
            'collapse_penalty': weights.get('collapse_penalty', None),
        }
    
    def log_state_action_space(self, state_info: Dict, action_info: Dict) -> None:
        """Log state and action space definitions."""
        self.run_data['state_space'] = state_info
        self.run_data['action_space'] = action_info
    
    def log_evaluation_metrics(self, metrics: Dict[str, float], agent_type: str = 'trained') -> None:
        """
        Log evaluation metrics.
        
        Args:
            metrics: Dict with keys: success_rate, avg_recovery_steps, avg_reward, std_reward
            agent_type: 'trained' or 'baseline'
        """
        metric_dict = {
            'success_rate': metrics.get('success_rate'),
            'avg_recovery_steps': metrics.get('avg_recovery_steps'),
            'avg_reward': metrics.get('avg_reward'),
            'std_reward': metrics.get('std_reward'),
        }
        
        if agent_type == 'trained':
            self.run_data['evaluation_metrics'] = metric_dict
        elif agent_type == 'baseline':
            self.run_data['baseline_metrics'] = metric_dict
    
    def calculate_improvement(self) -> None:
        """Calculate improvement metrics between trained and baseline."""
        trained = self.run_data['evaluation_metrics']
        baseline = self.run_data['baseline_metrics']
        
        if trained and baseline:
            success_improvement = (
                (trained['success_rate'] - baseline['success_rate']) / 
                baseline['success_rate'] * 100
                if baseline['success_rate'] > 0 else 0
            )
            
            reward_improvement = trained['avg_reward'] - baseline['avg_reward']
            
            speed_improvement = (
                (baseline['avg_recovery_steps'] - trained['avg_recovery_steps']) /
                baseline['avg_recovery_steps'] * 100
                if baseline['avg_recovery_steps'] > 0 else 0
            )
            
            self.run_data['improvement_metrics'] = {
                'success_rate_improvement_pct': success_improvement,
                'avg_reward_improvement': reward_improvement,
                'recovery_speed_improvement_pct': speed_improvement,
            }
    
    def save(self) -> str:
        """
        Save run data to JSON file.
        
        Returns:
            Path to saved file
        """
        if not self.run_dir:
            raise ValueError("No active run. Call create_run() first.")
        
        output_file = os.path.join(self.run_dir, 'training_log.json')
        
        # Convert numpy types to Python types for JSON serialization
        run_data_serializable = self._make_serializable(self.run_data)
        
        with open(output_file, 'w') as f:
            json.dump(run_data_serializable, f, indent=2)
        
        return output_file
    
    def _make_serializable(self, obj: Any) -> Any:
        """Convert numpy/pandas types to Python native types."""
        if isinstance(obj, dict):
            return {k: self._make_serializable(v) for k, v in obj.items()}
        elif isinstance(obj, (list, tuple)):
            return [self._make_serializable(item) for item in obj]
        elif isinstance(obj, (np.integer, np.floating)):
            return float(obj) if isinstance(obj, np.floating) else int(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif pd.isna(obj):
            return None
        else:
            return obj
    
    def get_summary(self) -> Dict[str, Any]:
        """Get current run summary."""
        return self.run_data
    
    @staticmethod
    def load_run(run_dir: str) -> Dict[str, Any]:
        """Load a previous training run from file."""
        log_file = os.path.join(run_dir, 'training_log.json')
        
        if not os.path.exists(log_file):
            raise FileNotFoundError(f"Log file not found: {log_file}")
        
        with open(log_file, 'r') as f:
            return json.load(f)
    
    @staticmethod
    def load_all_runs(results_dir: str = './training_results') -> List[Dict[str, Any]]:
        """Load all training runs for comparison."""
        runs = []
        
        if not os.path.exists(results_dir):
            return runs
        
        for run_folder in os.listdir(results_dir):
            run_path = os.path.join(results_dir, run_folder)
            if os.path.isdir(run_path):
                try:
                    run_data = RLTrainingLogger.load_run(run_path)
                    runs.append(run_data)
                except Exception as e:
                    print(f"Failed to load {run_folder}: {e}")
        
        # Sort by timestamp (newest first)
        runs.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        return runs
    
    @staticmethod
    def create_comparison_df(results_dir: str = './training_results') -> pd.DataFrame:
        """Create comparison DataFrame of all runs."""
        runs = RLTrainingLogger.load_all_runs(results_dir)
        
        comparison_data = []
        for run in runs:
            row = {
                'run_name': run.get('run_name'),
                'timestamp': run.get('timestamp'),
                'algorithm': run.get('training_config', {}).get('algorithm'),
                'learning_rate': run.get('training_config', {}).get('learning_rate'),
                'total_timesteps': run.get('training_config', {}).get('total_timesteps'),
                'success_rate': run.get('evaluation_metrics', {}).get('success_rate'),
                'avg_recovery_steps': run.get('evaluation_metrics', {}).get('avg_recovery_steps'),
                'avg_reward': run.get('evaluation_metrics', {}).get('avg_reward'),
                'improvement_pct': run.get('improvement_metrics', {}).get('success_rate_improvement_pct'),
            }
            comparison_data.append(row)
        
        return pd.DataFrame(comparison_data)


class RLTrainingAnalyzer:
    """Analyze training results and generate reports."""
    
    @staticmethod
    def print_run_summary(run_data: Dict[str, Any]) -> None:
        """Print formatted run summary."""
        print("\n" + "="*80)
        print(f"RUN: {run_data.get('run_name')}")
        print(f"TIMESTAMP: {run_data.get('timestamp')}")
        print("="*80)
        
        # Training Config
        print("\n📋 TRAINING CONFIG:")
        tc = run_data.get('training_config', {})
        print(f"  Algorithm: {tc.get('algorithm')}")
        print(f"  Total Timesteps: {tc.get('total_timesteps'):,}")
        print(f"  Learning Rate: {tc.get('learning_rate')}")
        print(f"  Gamma: {tc.get('gamma')}")
        print(f"  N Steps: {tc.get('n_steps')}")
        
        # Reward Weights
        print("\n⚖️ REWARD WEIGHTS:")
        rw = run_data.get('reward_weights', {})
        print(f"  α (Stability): {rw.get('alpha_stability')}")
        print(f"  β (Overhead): {rw.get('beta_overhead')}")
        print(f"  γ (Disruption): {rw.get('gamma_disruption')}")
        print(f"  δ (SLA): {rw.get('delta_sla')}")
        
        # Evaluation Metrics
        print("\n📊 EVALUATION METRICS:")
        em = run_data.get('evaluation_metrics', {})
        print(f"  Success Rate: {em.get('success_rate'):.1%}")
        print(f"  Avg Recovery Steps: {em.get('avg_recovery_steps'):.1f}")
        print(f"  Avg Reward: {em.get('avg_reward'):.3f}")
        
        # Baseline Metrics
        print("\n📊 BASELINE METRICS:")
        bm = run_data.get('baseline_metrics', {})
        print(f"  Success Rate: {bm.get('success_rate'):.1%}")
        print(f"  Avg Recovery Steps: {bm.get('avg_recovery_steps'):.1f}")
        print(f"  Avg Reward: {bm.get('avg_reward'):.3f}")
        
        # Improvement
        print("\n📈 IMPROVEMENT:")
        im = run_data.get('improvement_metrics', {})
        print(f"  Success Rate +{im.get('success_rate_improvement_pct'):.1f}%")
        print(f"  Recovery Speed +{im.get('recovery_speed_improvement_pct'):.1f}%")
        
        print("\n" + "="*80)
    
    @staticmethod
    def compare_runs(comparison_df: pd.DataFrame) -> None:
        """Print comparison of multiple runs."""
        print("\n" + "="*80)
        print("TRAINING RUNS COMPARISON")
        print("="*80)
        
        display_df = comparison_df[[
            'run_name', 'algorithm', 'learning_rate', 'success_rate',
            'avg_recovery_steps', 'avg_reward', 'improvement_pct'
        ]].copy()
        
        # Format for display
        display_df['success_rate'] = display_df['success_rate'].apply(lambda x: f"{x:.1%}")
        display_df['avg_reward'] = display_df['avg_reward'].apply(lambda x: f"{x:.3f}")
        display_df['improvement_pct'] = display_df['improvement_pct'].apply(lambda x: f"{x:+.1f}%")
        
        print("\n" + display_df.to_string(index=False))
        print("\n" + "="*80)
    
    @staticmethod
    def get_best_run(comparison_df: pd.DataFrame, metric: str = 'success_rate') -> Dict:
        """Get best run by metric."""
        if metric not in comparison_df.columns:
            raise ValueError(f"Metric {metric} not found in comparison data")
        
        best_idx = comparison_df[metric].idxmax()
        return comparison_df.iloc[best_idx].to_dict()


# Usage Example
if __name__ == '__main__':
    # Create logger
    logger = RLTrainingLogger('./training_results')
    
    # Create new run
    run_dir = logger.create_run()
    print(f"Created run: {run_dir}")
    
    # Log configurations
    logger.log_environment_config({
        'max_steps': 100,
        'num_deployments': 5,
        'num_nodes': 3,
    })
    
    logger.log_training_config({
        'algorithm': 'PPO',
        'total_timesteps': 250000,
        'learning_rate': 3.5e-4,
        'n_steps': 2048,
        'batch_size': 64,
        'gamma': 0.99,
    })
    
    logger.log_reward_weights({
        'alpha': 10.0,
        'beta': 3.5,
        'gamma': 2.5,
        'delta': 1.2,
    })
    
    # Log metrics
    logger.log_evaluation_metrics({
        'success_rate': 0.92,
        'avg_recovery_steps': 32.5,
        'avg_reward': -25.3,
        'std_reward': 15.2,
    }, agent_type='trained')
    
    logger.log_evaluation_metrics({
        'success_rate': 0.55,
        'avg_recovery_steps': 47.2,
        'avg_reward': -82.5,
        'std_reward': 35.1,
    }, agent_type='baseline')
    
    # Calculate improvement
    logger.calculate_improvement()
    
    # Save
    log_file = logger.save()
    print(f"Saved to: {log_file}")
    
    # Print summary
    RLTrainingAnalyzer.print_run_summary(logger.get_summary())
