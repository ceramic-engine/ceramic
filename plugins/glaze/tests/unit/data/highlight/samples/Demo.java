package demo;

import java.util.List;

/** Javadoc comment. */
@SuppressWarnings("unchecked")
public final class Demo<T extends Comparable<T>> implements Runnable {
    private static final int LIMIT = 10;
    private List<T> items;

    @Override
    public void run() {
        for (int i = 0; i < LIMIT; i++) {
            System.out.println("item " + i + '\t' + this.items.size());
        }
        boolean ok = items != null && !items.isEmpty();
        long big = 1_000_000L; double d = 2.5e-3;
    }
}
