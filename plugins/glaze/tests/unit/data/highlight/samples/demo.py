import os
from typing import List

# A comment with an accent: café
class Greeter(object):
    """Docstring of the class."""

    def __init__(self, name: str, count: int = 3) -> None:
        self.name = name
        self.count = count

    @property
    def greeting(self) -> str:
        return f"Hello {self.name}! \n" * self.count

def main(args: List[str]) -> int:
    pattern = r"^\d+(\.\d+)?$"
    values = [x ** 2 for x in range(10) if x % 2 == 0]
    print(Greeter("😀 world").greeting, len(values), None, True)
    return 0
