---
layout: post
title: JDK 源码阅读 - HashMap
tags: java hashmap
---

先从构造方法开始 HashMap 有四个构造方法:

1. HashMap(int initialCapacity, float loadFactor)
2. HashMap(int initialCapacity)
3. HashMap()
4. HashMap(Map<? extends K, ? extends V> m)

除开第四个方法使用现有的 Map 来构造一个 HashMap 外其他的三个都是一样的，只需要关注第一个即可。

这个构造方法有两个参数:

- initialCapacity 初始化大小
- loadFactor 扩容阈值的系数

initialCapacity 设置哈希表的初始化大小，但不是直接使用传入的值而是计算其最近的 2 次幂  

loadFactor 用来计算扩容的阈值，默认值是 0.75。例如默认的 capacity 是 16 那么阈值就是 12 在哈希表的大小大于 12 时就会进行扩容。  

```java
// initialCapacity map 的初始大小
// loadFactor 扩容阈值系数
public HashMap(int initialCapacity, float loadFactor) {
    if (initialCapacity < 0)
        throw new IllegalArgumentException("Illegal initial capacity: " + initialCapacity);
    if (initialCapacity > MAXIMUM_CAPACITY)
        // map 的最大容量位 1 << 30 = 1073741824
        initialCapacity = MAXIMUM_CAPACITY;
    if (loadFactor <= 0 || Float.isNaN(loadFactor))
        throw new IllegalArgumentException("Illegal load factor: " + loadFactor);
    // 设置阈值系数
    this.loadFactor = loadFactor;
    // 这个是扩容的阈值，但这里实际上给的值是初始的大小
    this.threshold = tableSizeFor(initialCapacity);
}

static final int tableSizeFor(int cap) {
    // -1 的二级制表示为 1111111111111111111111111111111
    // 将 -1 右移传入的值的二进制最高位之前的 0 的个数，这又就能得到其最近的 2 次幂
    int n = -1 >>> Integer.numberOfLeadingZeros(cap - 1);
    return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
}
```  

那么为什么需要使用 2 次幂来作为哈希表的大小，并且扩容是扩容成原来的两倍呢？  

在计算 key 的下标的时候是使用 key 的 hash & capacity - 1。我们可以假设，我们的 capacity 为 16，扩容后为32，我们还有两个 key，5 和 21。

5 进行下标计算  

> 101 & 1111 = 101 扩容后 => 101 & 11111 = 101 = 5

21 进行下标计算  

> 10101 & 1111 = 101 扩容后 => 10101 & 11111 = 10101 = 21  

可以发现如果我们的 key 的 hash 位数低于 capacity 位数，那么即使进行了扩容其下标也不需要变化；  
如果我们的 key 的 hash 的位树大于 capacity 位数，那么进行扩容后只需要将其下标加上扩容的大小就可以得到新的下标。  

除开构造方法，最常用的就是 put，remove 方法。  

这些方法之前还有一个关键的方法 hash(Object key) 用来计算 key 的 hash 值。  

- hash  

```java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

(h = key.hashCode()) ^ (h \>>> 16) 这里是用 key 的 hashCode 的高 16 位与低 16 位进行异或操作。由于 1.8 中引入了红黑树来处理链表过长的情况，所以这里不像 1.7 需要进行多次扰动，减少性能损失。而且因为 map 里哈希表的大小限制高位是不会参与计算的，这样使用高 16 位与低 16 位进行异或可以混合高低位的信息使高位参与到计算中。  

- put

```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}

final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    // 如果 tab 是空调用 resize 初始化
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    if ((p = tab[i = (n - 1) & hash]) == null)
        // 直接插入新结点
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        else if (p instanceof TreeNode)
            // 当前是红黑树
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {
            // 当前是链表
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    // 判断是否大于等于转换成树的阈值 TREEIFY_THRESHOLD = 8
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    // key 存在
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            // 已存在的 key 覆盖 value 并将旧 value 返回
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    // modCount 迭代器访问时阻止并发修改
    ++modCount;
    if (++size > threshold)
        // 如果容量大于阈值调用 resize 扩容
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

put 流程如下:  

1. 判断 hash 表是否为空，如果不为空则调用 resize() 方法进行初始化  

2. 根据 key 的 hash 计算其在 hash 表中的位置  

3. 如果当前位置为空则新建一个结点放在该位置  

4. 当前位置不为空，如果第一个结点的 key 和插入的 key 相等则使用新的 value 覆盖旧的 value，否则判断当前是链表还是红黑树  

5. 如果当前是红黑树则插入树中，如果当前是链表则进行尾插  

6. 链表尾插完成后判断当前链表长度是否大于 8，如果是那么在 hash 表长度大于 64 时将该链表转换成红黑树，否则进行扩容  

7. 如果当前 key 值已存在则返回旧的 value 插入完成  

8. 如果是新插入的 key 则 modeCount++ 容量 + 1 且判断 map 容量是否大于阈值，如果是进行扩容，然后返回 null  

- remove  

```java
public V remove(Object key) {
    Node<K,V> e;
    return (e = removeNode(hash(key), key, null, false, true)) == null ?
        null : e.value;
}

final Node<K,V> removeNode(int hash, Object key, Object value,
                           boolean matchValue, boolean movable) {
    Node<K,V>[] tab; Node<K,V> p; int n, index;
    // 如果 hash 表不为空，计算 key 下标
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (p = tab[index = (n - 1) & hash]) != null) {
        Node<K,V> node = null, e; K k; V v;
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            node = p;
        else if ((e = p.next) != null) {
            if (p instanceof TreeNode)
                // 当前是红黑树
                node = ((TreeNode<K,V>)p).getTreeNode(hash, key);
            else {
                // 当前是链表
                do {
                    if (e.hash == hash &&
                        ((k = e.key) == key ||
                         (key != null && key.equals(k)))) {
                        node = e;
                        break;
                    }
                    p = e;
                } while ((e = e.next) != null);
            }
        }
        if (node != null && (!matchValue || (v = node.value) == value ||
                             (value != null && value.equals(v)))) {
            if (node instanceof TreeNode)
                // 移除树结点
                ((TreeNode<K,V>)node).removeTreeNode(this, tab, movable);
            else if (node == p)
                // 移除链表结点
                tab[index] = node.next;
            else
                p.next = node.next;
            // modCount 迭代器访问时阻止并发修改
            ++modCount;
            --size;
            afterNodeRemoval(node);
            return node;
        }
    }
    return null;
}
```

remove 流程如下:  

1. 根据 key 的 hash 计算其在 hash 表中的位置  

2. 如果第一个结点的 key 就是当前 key 则获取当前结点，否则判断是链表还是红黑树  

3. 如果是红黑树查找 key 对应的结点  

4. 如果是链表遍历链表查找 key 对应的结点  

5. 如果存在 key 对应的结点，将该结点删除 modCount-- 容量 - 1
