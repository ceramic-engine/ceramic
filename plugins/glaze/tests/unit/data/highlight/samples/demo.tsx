import React, { useState } from "react";

type Props = { title: string; count?: number };

export function Counter({ title, count = 0 }: Props): JSX.Element {
  const [value, setValue] = useState<number>(count);
  return (
    <div className="counter" onClick={() => setValue(value + 1)}>
      <h1>{title}</h1>
      {value > 3 && <span>Big: {value}</span>}
    </div>
  );
}
