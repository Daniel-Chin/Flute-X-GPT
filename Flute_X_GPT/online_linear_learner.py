import torch
from torch.optim.adam import Adam

class OnlineLinearLearner:
    def __init__(self, guess_k: float, guess_b: float, lr: float) -> None:
        self.k = torch.tensor(
            guess_k, dtype=torch.float32, requires_grad=True, 
        )
        self.b = torch.tensor(
            guess_b, dtype=torch.float32, requires_grad=True, 
        )
        self.optimizer = Adam([self.k, self.b], lr=lr)
    
    def forward(self, x: float):
        return self.k * x + self.b
    
    def train(self, x: float, y: float):
        pred = self.forward(x)
        loss = (pred - y) ** 2
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()
        return pred.item()
    
    def print(self):
        print(f'k = {self.k.item()}, b = {self.b.item()}')
