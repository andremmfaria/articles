---
title: Mastering Technical Interviews A Practical Guide to the Algorithms That Appear Again and Again
tags:
  - coding
  - interviews
  - algorithms
published: false
cover_image: 'https://images.klipfolio.com/website/public/11f3da89-351a-4ca1-a59d-b6806b0fcec1/algorithm.jpg'
---

Technical interviews at top-tier companies consistently revolve around a core set of algorithmic patterns. These patterns—two pointers, sliding windows, heaps, graph traversals, dynamic programming, and others—form the foundation of modern problem-solving in software engineering. Understanding *when* to use each technique is as important as knowing *how* to implement it.

This guide distils the essential algorithms every candidate should know, explains the scenarios where each approach is most effective, and provides clear templates you can rely on during high-pressure interview settings. Whether preparing for Meta, Google, or any other systems-oriented role, these patterns will equip you with the mental shortcuts and implementation strategies needed to solve problems efficiently and confidently.

## 1. Two Pointers

Two pointers are useful when an array or string must be processed from two directions or when you need to maintain a pair of indices representing a candidate solution. This approach reduces nested loops into linear scans. It is most effective when the input is sorted, or when the problem involves distances, sums, comparisons between ends, or in-place modifications without extra memory.

Use when:

* The array is sorted or can be sorted.
* The task involves pairwise relationships: sum to target, maximize or minimize distance, compare left vs. right properties.
* The problem asks for in-place rearrangement or partitioning.
* You want to eliminate a nested loop and reduce complexity from O(n²) to O(n).

Typical patterns:

* Opposite-direction pointers moving toward each other (summing, container area, water trapping).
* Same-direction pointers, where one pointer marks the “write” position (Move Zeroes, Dutch Flag sorting).

Example template (sum-based):

```python
l, r = 0, len(nums) - 1
while l < r:
    s = nums[l] + nums[r]
    if s == target:
        return [l, r]
    elif s < target:
        l += 1
    else:
        r -= 1
```

Example template (in-place compaction):

```python
def moveZeroes(nums):
    insert = 0
    for i in range(len(nums)):
        if nums[i] != 0:
            nums[insert], nums[i] = nums[i], nums[insert]
            insert += 1
```

---

## 2. Sliding Window

Sliding windows handle problems involving contiguous subarrays or substrings. The key idea is maintaining a window [l, r] with properties that can be updated as r expands and l contracts. This avoids recomputation and typically yields O(n) complexity. Sliding windows come in fixed-size and variable-size forms.

Use when:

* The problem explicitly requires considering contiguous sequences.
* The goal is to maximize/minimize length, find the longest substring with constraints, or compute sums efficiently.
* There is a property that can be updated incrementally when the window expands or shrinks.
* Hash maps or counters are used to track window validity.

Fixed-size window:

* Used when the window size is given (e.g., “subarray of size k”).
* Simply slide by removing leftmost element and adding rightmost.

Variable-size window:

* Used when the window grows until invalid and then shrinks to restore validity.
* Common in distinct-character constraints or frequency-based problems.

Example fixed-size:

```python
def max_sum_subarray(nums, k):
    window_sum = sum(nums[:k])
    best = window_sum
    for i in range(k, len(nums)):
        window_sum += nums[i] - nums[i - k]
        best = max(best, window_sum)
    return best
```

Example variable-size:

```python
def lengthOfLongestSubstring(s):
    seen = {}
    l = 0
    best = 0
    for r, ch in enumerate(s):
        if ch in seen and seen[ch] >= l:
            l = seen[ch] + 1
        seen[ch] = r
        best = max(best, r - l + 1)
    return best
```

---

## 3. Intervals

Interval problems revolve around operations on ranges [start, end]. Solutions almost always begin with sorting intervals, and reasoning about overlaps, merges, or gaps. Correct management of boundaries is essential. Many problems reduce to merging, insertion, or counting overlapping intervals.

Use when:

* Input consists of ranges and you must merge, insert, or count overlaps.
* You are asked whether intervals overlap or conflict.
* You must determine available or free time.
* Greedy techniques become effective after sorting by start or end times.

Core techniques:

* Sort by start time when merging or inserting.
* Sort by end time when minimizing conflicts.
* Maintain a running "current end" to detect overlap or free space.

Example merge:

```python
def merge(intervals):
    intervals.sort(key=lambda x: x[0])
    res = []
    for s, e in intervals:
        if not res or s > res[-1][1]:
            res.append([s, e])
        else:
            res[-1][1] = max(res[-1][1], e)
    return res
```

Example non-overlapping (minimum removals):

```python
def eraseOverlapIntervals(intervals):
    intervals.sort(key=lambda x: x[1])
    count = 0
    last_end = float('-inf')
    for s, e in intervals:
        if s >= last_end:
            last_end = e
        else:
            count += 1
    return count
```

---

## 4. Stack

Stacks are suitable for problems involving nested structures, reversing order, parsing, or tracking monotonic sequences. A stack keeps context: what has been seen but not yet closed or resolved. Monotonic stacks allow efficient next-greater-element or histogram computations.

Use when:

* Parentheses or encoded strings must be validated or decoded.
* You need "previous greater/smaller" or "next greater/smaller".
* Problems require evaluating expressions or parsing nested formats.
* You want to track elements in sorted order while maintaining O(n) amortized time.

Patterns:

* Classic push/pop for matching delimiters.
* Monotonic stack: maintain increasing or decreasing order to compute ranges efficiently.

Example parentheses:

```python
def isValid(s):
    stack = []
    pair = {')': '(', ']': '[', '}': '{'}
    for ch in s:
        if ch in '([{':
            stack.append(ch)
        else:
            if not stack or stack[-1] != pair[ch]:
                return False
            stack.pop()
    return not stack
```

Example monotonic (Daily Temperatures):

```python
def dailyTemperatures(T):
    res = [0] * len(T)
    stack = []
    for i, temp in enumerate(T):
        while stack and T[stack[-1]] < temp:
            j = stack.pop()
            res[j] = i - j
        stack.append(i)
    return res
```

---

## 5. Linked List

Linked list techniques rely on pointer manipulation, often requiring careful handling of node references. Many solutions hinge on using fast/slow pointers to detect cycles, identify midpoints, or perform operations relative to the end of the list. Extra memory is usually unnecessary, and elegance depends on pointer management.

Use when:

* You must detect cycles or intersections.
* The task involves reversing part or all of a list.
* Operations depend on the nth node from the end.
* You must reorder nodes without converting to arrays.

Patterns:

* Fast/slow pointer to find cycles or midpoints.
* Dummy nodes to simplify edge-case manipulation.
* Two-pointer offset technique for “remove nth from end”.

Example cycle detection:

```python
def hasCycle(head):
    slow = fast = head
    while fast and fast.next:
        slow = slow.next
        fast = fast.next.next
        if slow == fast:
            return True
    return False
```

Example remove nth:

```python
def removeNthFromEnd(head, n):
    dummy = ListNode(0, head)
    slow = fast = dummy
    for _ in range(n):
        fast = fast.next
    while fast.next:
        slow = slow.next
        fast = fast.next
    slow.next = slow.next.next
    return dummy.next
```

---

## 6. Binary Search

Binary search applies to sorted arrays or to problems where the answer lies in a monotonic search space. You can binary-search over indices, values, or even abstract answers (binary search on “feasibility”). A solution is valid if increasing or decreasing the parameter changes feasibility in a predictable (monotonic) way.

Use when:

* The array is sorted, rotated, or partially sorted.
* The problem asks for first/last occurrence, boundary, or pivot index.
* You can express the question as: “Is x feasible?” and feasibility changes monotonically.
* You must optimize or minimize some parameter, such as speed, capacity, or rate.

Patterns:

* Standard binary search on sorted arrays.
* Modified binary search for rotated sorted arrays.
* Binary search on answer when the value domain is large but checking feasibility is O(n).

Example binary search:

```python
def binary_search(nums, target):
    l, r = 0, len(nums) - 1
    while l <= r:
        mid = (l + r) // 2
        if nums[mid] == target:
            return mid
        elif nums[mid] < target:
            l = mid + 1
        else:
            r = mid - 1
    return -1
```

Example binary search on answer (Koko Eating Bananas):

```python
import math

def minEatingSpeed(piles, h):
    l, r = 1, max(piles)
    while l < r:
        m = (l + r) // 2
        hours = sum(math.ceil(p / m) for p in piles)
        if hours <= h:
            r = m
        else:
            l = m + 1
    return l
```

---

## 7. Heap (Priority Queue)

Heaps are ideal when the problem requires repeatedly extracting the minimum or maximum element, or maintaining a dynamic set where only the top-k items matter. They guarantee O(log n) insertion and extraction and are essential when selecting the smallest/largest elements without fully sorting. Heaps shine in multi-way merging, streaming problems, and any scenario where you need efficient “best candidate” retrieval.

Use when:

* The task asks for the k smallest/largest items.
* You need to continuously push/pop values while keeping only the top k.
* You must merge multiple sorted lists or streams.
* A greedy algorithm relies on always selecting the current minimum or maximum.

Patterns:

* **Min-heap** for selecting smallest; use negative values for max-heap behavior.
* **Size-k heaps** to ensure O(n log k) solutions.
* **Tuples in heaps** for ordering by multiple properties.

Example: Kth Largest Element

```python
import heapq

def findKthLargest(nums, k):
    heap = nums[:k]
    heapq.heapify(heap)
    for x in nums[k:]:
        if x > heap[0]:
            heapq.heapreplace(heap, x)
    return heap[0]
```

Example: Merge K Sorted Lists

```python
import heapq

def mergeKLists(lists):
    heap = []
    for i, node in enumerate(lists):
        if node:
            heapq.heappush(heap, (node.val, i, node))
    dummy = ListNode(0)
    cur = dummy
    while heap:
        val, i, node = heapq.heappop(heap)
        cur.next = node
        cur = node
        if node.next:
            heapq.heappush(heap, (node.next.val, i, node.next))
    return dummy.next
```

---

## 8. Depth-First Search (DFS)

DFS is used for exploring deep paths in trees or graphs, inspecting components, and performing recursive structural computations. It is especially useful when the problem requires visiting all nodes in a connected component, generating all possible paths, or computing metrics that depend on recursive aggregation. DFS works on both trees and general graphs, using visited sets to avoid cycles.

Use when:

* The problem requires exploring all paths or all nodes in a region.
* Tree problems that involve computing depth, height, tilt, diameter, or checking validity.
* Graph problems involving connected components, cloning, or traversal.
* Grid problems identifying islands, regions, or flood fill behavior.

Patterns:

* Recursive DFS for tree or grid problems.
* Stack-based DFS for graph problems.
* Mark visited nodes to prevent infinite loops.

Example: Maximum Depth of Binary Tree

```python
def maxDepth(root):
    if not root:
        return 0
    return 1 + max(maxDepth(root.left), maxDepth(root.right))
```

Example: Number of Islands (grid DFS)

```python
def numIslands(grid):
    rows, cols = len(grid), len(grid[0])

    def dfs(r, c):
        if r < 0 or c < 0 or r >= rows or c >= cols or grid[r][c] != '1':
            return
        grid[r][c] = '0'
        dfs(r+1, c)
        dfs(r-1, c)
        dfs(r, c+1)
        dfs(r, c-1)

    count = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == '1':
                count += 1
                dfs(r, c)
    return count
```

---

## 9. Breadth-First Search (BFS)

BFS excels at shortest-path problems on unweighted graphs, level-order processing in trees, and multi-source propagation (spreading effects over steps). BFS processes nodes layer by layer, guaranteeing the minimum number of steps to reach targets. It is the appropriate choice when the question involves minimum distances, time steps, or systematic level traversal.

Use when:

* The problem asks for the shortest number of steps in an unweighted setting.
* You must process a tree or graph level by level.
* Multi-source diffusion problems: rotting oranges, spread of signals, BFS from multiple starting states.
* Grid problems requiring finding the minimal distance to something.

Patterns:

* Use a queue and process nodes per level.
* Use visited sets for cycles in graphs.
* Push all initial sources before starting (multi-source BFS).

Example: Level Order Traversal

```python
from collections import deque

def levelOrder(root):
    if not root:
        return []
    q = deque([root])
    res = []
    while q:
        level = []
        for _ in range(len(q)):
            node = q.popleft()
            level.append(node.val)
            if node.left: q.append(node.left)
            if node.right: q.append(node.right)
        res.append(level)
    return res
```

Example: Rotting Oranges (multi-source BFS)

```python
from collections import deque

def orangesRotting(grid):
    rows, cols = len(grid), len(grid[0])
    q = deque()
    fresh = 0

    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == 2:
                q.append((r, c, 0))
            elif grid[r][c] == 1:
                fresh += 1

    minutes = 0
    while q:
        r, c, t = q.popleft()
        minutes = max(minutes, t)
        for dr, dc in ((1,0),(-1,0),(0,1),(0,-1)):
            nr, nc = r+dr, c+dc
            if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] == 1:
                grid[nr][nc] = 2
                fresh -= 1
                q.append((nr, nc, t + 1))

    return minutes if fresh == 0 else -1
```

---

## 10. Backtracking

Backtracking is the algorithmic backbone for generating all valid configurations under constraints. It searches through the solution space using depth-first exploration while pruning invalid options as early as possible. This allows concise solutions for combinatorial problems, exhaustive enumeration, and constructing sequences step-by-step while maintaining validity.

Use when:

* The problem requires generating all subsets, permutations, or combinations.
* There is a need to explore choices step-by-step while respecting constraints.
* Validity can be checked incrementally, allowing pruning of branches.
* Search space is exponential and requires efficient pruning.

Patterns:

* Recursive function with state `path` and decision index.
* Undo action (`path.pop()`) after exploring each branch.
* Prune early when the partial solution already violates constraints.

Example: Subsets

```python
def subsets(nums):
    res = []
    def dfs(i, path):
        if i == len(nums):
            res.append(path[:])
            return
        dfs(i+1, path)
        path.append(nums[i])
        dfs(i+1, path)
        path.pop()
    dfs(0, [])
    return res
```

Example: Generate Parentheses

```python
def generateParenthesis(n):
    res = []
    def backtrack(path, open_count, close_count):
        if len(path) == 2*n:
            res.append(path)
            return
        if open_count < n:
            backtrack(path + "(", open_count + 1, close_count)
        if close_count < open_count:
            backtrack(path + ")", open_count, close_count + 1)
    backtrack("", 0, 0)
    return res
```

---

## 11. Graphs (Topological Sort)

Topological sort is applied to directed acyclic graphs when you must determine an order of tasks respecting prerequisites. Cycle detection is inherent: if no valid ordering exists, the graph contains a cycle. It is frequently used for scheduling, dependency resolution, and course prerequisite problems.

Use when:

* The problem mentions prerequisites, dependencies, ordering, or sequence validity.
* You must determine if a cycle exists in a directed graph.
* You must output a valid order of completion.
* Nodes represent tasks; edges represent dependencies.

Patterns:

* Compute in-degree of nodes.
* Use a queue to process nodes with in-degree zero.
* Remove edges gradually and collect nodes in order.

Example: Can Finish (detect feasibility)

```python
from collections import defaultdict, deque

def canFinish(numCourses, prerequisites):
    graph = defaultdict(list)
    indegree = [0] * numCourses
    for a, b in prerequisites:
        graph[b].append(a)
        indegree[a] += 1

    q = deque(i for i in range(numCourses) if indegree[i] == 0)
    taken = 0
    while q:
        u = q.popleft()
        taken += 1
        for v in graph[u]:
            indegree[v] -= 1
            if indegree[v] == 0:
                q.append(v)
    return taken == numCourses
```

Example: Course Schedule II (return ordering)

```python
def findOrder(numCourses, prerequisites):
    from collections import defaultdict, deque
    graph = defaultdict(list)
    indegree = [0] * numCourses
    for a, b in prerequisites:
        graph[b].append(a)
        indegree[a] += 1

    q = deque(i for i in range(numCourses) if indegree[i] == 0)
    order = []
    while q:
        u = q.popleft()
        order.append(u)
        for v in graph[u]:
            indegree[v] -= 1
            if indegree[v] == 0:
                q.append(v)
    return order if len(order) == numCourses else []
```

---

## 12. Dynamic Programming (DP)

Dynamic programming is appropriate when a problem can be decomposed into overlapping subproblems with optimal substructure. DP trades space for time, storing intermediate results to avoid recomputation. Problems involving counting ways, optimizing values, or building solutions from smaller components often map directly to DP formulations.

Use when:

* Optimal solutions depend on solutions to smaller subproblems.
* The problem has overlapping subproblems and cannot be solved greedily.
* You recognize patterns like knapsack, subsequences, paths, decoding, or interval DP.
* The recurrence relation naturally emerges from the problem statement.

Types:

* **1D DP** for sequences (Decode Ways, Word Break).
* **2D DP** for grids (Unique Paths, Maximal Square).
* **DP + binary search** for LIS-style problems.
* **DP on intervals** or structure-dependent DP when combining segments.

Example: Decode Ways

```python
def numDecodings(s):
    if not s or s[0] == '0':
        return 0
    dp = [0] * (len(s)+1)
    dp[0] = dp[1] = 1
    for i in range(2, len(s)+1):
        if s[i-1] != '0':
            dp[i] += dp[i-1]
        if 10 <= int(s[i-2:i]) <= 26:
            dp[i] += dp[i-2]
    return dp[-1]
```

Example: Longest Increasing Subsequence (DP + binary search)

```python
import bisect

def lengthOfLIS(nums):
    dp = []
    for x in nums:
        i = bisect.bisect_left(dp, x)
        if i == len(dp):
            dp.append(x)
        else:
            dp[i] = x
    return len(dp)
```

---

## 13. Greedy Algorithms

Greedy algorithms make locally optimal decisions at each step with the expectation that these choices lead to a global optimum. They rely on the problem having a structure where greedy-choice and optimal substructure properties naturally hold. Once you commit to a choice, you do not revisit it, making solutions efficient and typically O(n) or O(n log n).

Use when:

* The problem can be solved by repeatedly taking the best immediate option.
* Sorting helps reveal an order that makes greedy decisions valid.
* You are maximizing or minimizing a metric such as profit, number of intervals, or fuel balance.
* Backtracking or DP is unnecessary because future steps do not depend on alternative past choices.

Patterns:

* Track running min/max (Best Time to Buy/Sell Stock).
* Maintain cumulative resource balance (Gas Station).
* Advance by the farthest reachable index each step (Jump Game).

Example: Best Time to Buy and Sell Stock

```python
def maxProfit(prices):
    min_price = float('inf')
    best = 0
    for p in prices:
        min_price = min(min_price, p)
        best = max(best, p - min_price)
    return best
```

Example: Jump Game

```python
def canJump(nums):
    reachable = 0
    for i, jump in enumerate(nums):
        if i > reachable:
            return False
        reachable = max(reachable, i + jump)
    return True
```

---

## 14. Trie

Tries efficiently store and query large sets of strings, especially when prefix operations are frequent. They organize characters in a tree-like structure where each path from root to node represents a prefix. Tries allow O(m) lookup where m is the word length, independent of how many words exist. They are fundamental for autocomplete, prefix filtering, and dictionary checks.

Use when:

* The task involves prefix search or prefix matching.
* You must repeatedly query or insert strings with overlapping prefixes.
* Problems ask whether any word starts with a given prefix.
* Searching character-by-character offers more efficiency than scanning all strings.

Patterns:

* Each node contains a map of children.
* Mark `end = True` for completed words.
* Walk the trie for searching or prefix validation.

Example: Trie Implementation

```python
class TrieNode:
    def __init__(self):
        self.children = {}
        self.end = False

class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word):
        node = self.root
        for ch in word:
            node = node.children.setdefault(ch, TrieNode())
        node.end = True

    def search(self, word):
        node = self.root
        for ch in word:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return node.end

    def startsWith(self, prefix):
        node = self.root
        for ch in prefix:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return True
```

Example use case indicator:

* Input: many words, many queries → trie fits.
* Task: “return the number of words with a given prefix” or “determine if any word begins with prefix”.

---

## 15. Prefix Sum

Prefix sums transform cumulative operations into O(1) queries by precomputing running totals. They allow rapid calculation of subarray sums, difference queries, and frequency-based insights. Instead of recomputing from scratch, you subtract two prefix values to get the sum of any range.

Use when:

* The problem involves frequent sum-of-subarray queries.
* You must detect subarrays with a target sum or pattern.
* Overlapping subarrays need efficient comparison.
* A running balance or cumulative measure is helpful.

Patterns:

* `prefix[i] = nums[0] + ... + nums[i-1]`
* Subarray sum from i to j: prefix[j+1] – prefix[i]
* Hash map of prefix sums to detect subarrays with specific targets.

Example: Subarray Sum Equals K

```python
from collections import defaultdict

def subarraySum(nums, k):
    prefix = 0
    count = 0
    freq = defaultdict(int)
    freq[0] = 1
    for x in nums:
        prefix += x
        count += freq[prefix - k]
        freq[prefix] += 1
    return count
```

Example use cases:

* “Count subarrays with sum k.”
* “Find how many substrings satisfy some cumulative constraint.”

---

## 16. Matrices

Matrix problems require structured 2D traversal, manipulation, or transformation. Many tasks involve row/column operations, rotation, flooding, or spiral traversal. Solutions often rely on systematic scans or in-place transformations to maintain O(1) space. Index manipulation is the core challenge: understanding how rows and columns shift relative to one another.

Use when:

* The question involves grid-based movement or transformations.
* Problems require rotating, flipping, zeroing rows and columns.
* Spiral-order traversal or layer-by-layer operations apply.
* 2D constraints create natural boundaries for iteration.

Patterns:

* Use boundary pointers for spirals.
* Matrix transpositions and reversals for rotations.
* Row/column flags for operations like Set Matrix Zeroes.

Example: Spiral Matrix

```python
def spiralOrder(matrix):
    res = []
    top, bottom = 0, len(matrix)-1
    left, right = 0, len(matrix[0])-1

    while top <= bottom and left <= right:
        for c in range(left, right+1):
            res.append(matrix[top][c])
        top += 1

        for r in range(top, bottom+1):
            res.append(matrix[r][right])
        right -= 1

        if top <= bottom:
            for c in range(right, left-1, -1):
                res.append(matrix[bottom][c])
            bottom -= 1

        if left <= right:
            for r in range(bottom, top-1, -1):
                res.append(matrix[r][left])
            left += 1

    return res
```

Example: Rotate Image (90° clockwise)

```python
def rotate(matrix):
    n = len(matrix)
    for i in range(n):
        for j in range(i+1, n):
            matrix[i][j], matrix[j][i] = matrix[j][i], matrix[i][j]  # transpose
    for row in matrix:
        row.reverse()
```

Example: Set Matrix Zeroes

* First pass: mark zero rows and columns.
* Second pass: zero out cells in marked rows/columns.
