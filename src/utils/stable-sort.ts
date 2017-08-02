
interface Comparator<T> {
    (a: T, b: T): number;
}
interface Array<T> {
    stableSort(cmp?: Comparator<T>): Array<T>;
}

let defaultCmp: Comparator<any> = (a, b) => {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
};
    
export function stableSort<T>(self:T[], cmp:Comparator<T> = defaultCmp): T[] {
    let stabilized = self.map((el, index) => <[T, number]>[el, index]);
    let stableCmp: Comparator<[T, number]> = (a, b) => {
        let order = cmp(a[0], b[0]);
        if (order !== 0) return order;
        return a[1] - b[1];
    };

    stabilized.sort(stableCmp);
    for (let i = 0; i < self.length; i++) {
        self[i] = stabilized[i][0];
    }

    return self;
}
