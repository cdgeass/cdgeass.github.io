---
title: Java 偏向锁
date: 2025-08-01 15:59:18
categories: 
tags:
  - Java
---
偏向锁于 JDK1.6 引入，JDK15 中已被废弃，可以通过参数 `-XX:+UseBiasedLocking` 启用。

早期线程安全的集合如 HashTable，Vector 等都依赖于 synchronized，而大多数情况下不存在线程竞争，使用偏向锁可以减少这种情况下的同步开销，偏向锁会偏向于第一个获取它的线程。

当有其他线程尝试获取锁时偏向锁会进行撤销操作。撤销操作需要等待全局安全点，暂停持有锁的线程并检查是否在执行同步块中的代码，如果是则升级为轻量锁，否则其他线程可以竞争该锁。所以高并发的场景偏向锁会导致STW时间过长，于是在 JDK15 中被弃用。

### 对象头

64位虚拟机为例，偏向锁的Mark Word结构如下。

| 54bit  | 2bit  | 1bit | 4bit | 1bit   | 2bit |
| ------ | ----- | ---- | ---- | ------ | ---- |
| 偏向线程ID | Epoch |      | 年龄   | 偏向锁标志位 | 01   |

### 偏向锁延迟

由于 JVM 内部大量使用 synchronized 来保证线程安全而之前说过频繁的偏向锁撤销会带来额外的开销，所以 JVM 在启动后会延迟一段时间（默认为4秒）才启用偏向锁。

我们使用 jol 来打印对象头的信息，以观察偏向锁的状态。

```xml
<dependency>
    <groupId>org.openjdk.jol</groupId>
    <artifactId>jol-core</artifactId>
    <version>0.17</version>
</dependency>
```

新生成的对象处于无锁不偏向的状态，此时获取到的锁为轻量级锁。

延迟5秒以确保偏向锁已启用。此时新生成的对象为匿名偏向状态，偏向锁标志位为1，但存储的线程id为空。

在获取锁后偏向锁偏向当前线程。

```java
/**
 * 添加 jvm 参数确保启用偏向锁以及延迟4000毫秒启动 -XX:+UseBiasedLocking -XX:BiasedLockingStartupDelay=4000
 */
public static void biasedLock() {
    Object lock = new Object();
    System.out.println("无锁不可偏向");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());

    synchronized (lock) {
        System.out.println("轻量级锁");
        System.out.println(ClassLayout.parseInstance(lock).toPrintable());
    }

    try {
        Thread.sleep(5000);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }

    lock = new Object();
    System.out.println("匿名偏向");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());

    synchronized (lock) { }
	
    System.out.println("偏向当前线程");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());
}
```

### 批量重偏向

由于多个线程频繁竞争偏向锁而产生的撤销和升级带来的性能消耗 JVM 引入了批量重偏向的机制，当一个类的对象发生偏向锁撤销的次数达到了阈值（默认20）就会触发批量重偏向。

当发生批量重偏向时首先会将对应类的 epoch 值加 1。

然后遍历处于锁定状态的对象将其对象头中的 epoch 更新为类中的值。

未被锁定状态的对象的 epoch 值则不会更新，当尝试获取锁是会发现其与类中的 epoch 值不一致，那么 JVM 就不会进行偏向锁撤销而是使用 CAS 操作将其偏向为新的线程。

下面的代码演示了批量重偏向的过程。

第19个对象因为此前偏向于线程1后被线程2持有锁，此时获取到的是轻量级锁。

第20个对象获取锁时发生了批量重偏向，获取到的为偏向锁，偏向线程2。

第1个对象在批量重偏向发生之前获取到的是轻量级锁，锁释放后处于无锁状态，且再获取锁为轻量级锁。

第25个对象在批量重偏向发生之后则处于偏向锁状态，偏向线程2。

```java
/**
 * 批量重偏向测试
 *
 * 添加 jvm 参数指定批量重偏向阈值为20 -XX:BiasedLockingBulkRebiasThreshold=20
 */
public static void batchRebiased() {
    try {
        Thread.sleep(5000);
    } catch (InterruptedException e) {
    }

    List<Object> locks = new ArrayList<>();
    for (int i = 0; i < 30; i++) {
        locks.add(new Object());
    }

    t1 = new Thread(() -> {
        for (Object lock : locks) {
            synchronized (lock) { }
        }

        LockSupport.unpark(t2);
    });

    t2 = new Thread(() -> {
        LockSupport.park();
		
        for (int i = 0; i < 30; i++) {
            Object lock = locks.get(i);
            synchronized (lock) {
                if (i == 18 || i == 19) {
                    System.out.println("第" + (i + 1) + "个对象，同步中:");
                    System.out.println(ClassLayout.parseInstance(lock).toPrintable());
                }
            }

            if (i == 19) {
                System.out.println("第20个对象释放后:");
                System.out.println(ClassLayout.parseInstance(lock).toPrintable());
            }
        }
    });

    t1.start();
    t2.start();

    try {
        t2.join();
    } catch (InterruptedException e) {
    }

    System.out.println("第1个对象最终状态:");
    System.out.println(ClassLayout.parseInstance(locks.get(0)).toPrintable());

    System.out.println("第25个对象最终状态:");
    System.out.println(ClassLayout.parseInstance(locks.get(24)).toPrintable());
}
```

### 批量撤销

当竞争更次数更进一步时到达一定阈值时（默认40） JVM 会认为该类不适合使用偏向锁，触发批量撤销。

批量撤销发生后会将该类标记为不可偏向，撤销现有对象的偏向锁，处于锁定状态的对象会升级成轻量级锁，新创建的对象会处于无锁不可偏向状态。

下面代码通过多个线程竞争演示了批量撤销，批量撤销后所有对象均处于无锁不可偏向状态。

```java
/**
 * 批量撤销测试
 *
 * 添加 jvm 参数指定批量撤销值为40 -XX:BiasedLockingBulkRevokeThreshold=40
 */
public static void batchRevoked() {
    try {
        Thread.sleep(5000);
    } catch (InterruptedException e) {
    }
	
    final List<Object> locks = new ArrayList<>();
    for (int i = 0; i < 100; i++) {
        locks.add(new Object());
    }

    final int threadCount = 40;
    final CountDownLatch startLatch = new CountDownLatch(1);
    final CountDownLatch endLatch = new CountDownLatch(threadCount);

    for (int i = 0; i < threadCount; i++) {
        new Thread(() -> {
            try {
                startLatch.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            for (int j = 0; j < 60; j++) {
                Object lock = locks.get(j);
                synchronized (lock) {
                }
            }
            endLatch.countDown();
        }).start();
    }

    startLatch.countDown();
    try {
        endLatch.await();
    } catch (InterruptedException e) {
    }

    System.out.println("第1个对象最终状态:");
    System.out.println(ClassLayout.parseInstance(locks.get(0)).toPrintable());

    System.out.println("第45个对象最终状态:");
    System.out.println(ClassLayout.parseInstance(locks.get(44)).toPrintable());

    System.out.println("批量撤销后，新创建的对象状态:");
    Object newLock = new Object();
    System.out.println(ClassLayout.parseInstance(newLock).toPrintable());
}
```
