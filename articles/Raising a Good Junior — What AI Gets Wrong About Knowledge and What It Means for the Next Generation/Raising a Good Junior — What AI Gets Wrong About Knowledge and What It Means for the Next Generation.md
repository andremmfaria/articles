---
title: 'Raising a Good Junior: What AI Gets Wrong About Knowledge and What It Means for the Next Generation'
description: 'A reflection on tacit knowledge, the apprenticeship model, and what it means to raise a child in a world where AI is a de facto tool.'
published: true
cover_image: 'https://images.unsplash.com/photo-1758687126445-98edd4b15ba6?w=1200&fm=jpg&q=80'
tags:
  - ai
  - education
  - engineering
  - softskills
id: 3712038
---

A friend of mine, Jose, sent me a conversation he'd had with an AI assistant about an article he'd been reading. The article was [The Tacit Dimension](https://cekrem.github.io/posts/the-tacit-dimension/) by Christian Ekrem. Jose's observation was sharp: he'd been frustrated by the same thing the article describes, AI assistants that produce confident output without surfacing any of the reasoning behind it, the implicit design decisions staying implicit. The conversation he shared was good enough that I went and read the article itself.

It made me put my phone down. Not because it was wrong, but because it was pointing at something real and uncomfortable, and because it immediately made me think about my son.

The article builds on Michael Polanyi's 1966 claim: *we can know more than we can tell*. Polanyi's observation was that expert knowledge is structurally tacit. It lives in the body, in practice, in the pattern-recognition accumulated over years of doing a thing. You can't extract it. You can't train a model on it, because it was never written down. And you can't transfer it except by working alongside someone who has it.

Ekrem applies this to AI-assisted software development and argues we are sleepwalking into a crisis: juniors are being apprenticed to AI assistants instead of to seniors, the "why does this work this way?" questions are drying up, and the tacit knowledge that used to flow through teams is quietly bankrupting out of codebases. The seniors retire. Nobody knows why the auth system works the way it does. The code keeps running.

It's a well-argued piece. But it has a gap in it, and that gap leads somewhere interesting.

---

## Where the Argument Holds

Ekrem's strongest point isn't about AI. It's about what happens when any shortcut severs the connection between doing and understanding.

His illustration is a colleague who spent an afternoon refusing to merge a PR that was technically correct. Tests passing, CI green, everything fine on paper. He kept saying "I just don't believe this code." Forty minutes into walking the author through it line by line, the author said offhand: *"this assumes the queue is FIFO, but I think that's safe."* It wasn't. The queue was FIFO in development and best-effort-FIFO in production, buried in a runbook nobody had read in two years.

The colleague had smelled it from the diff. Not from reading a document. From a decade of looking at similar things and accumulating a mental model of where pain tends to come from. That kind of knowledge doesn't show up in any training corpus because it was never written down in any single place. It was always distributed across experience, context, and memory.

An AI can't replicate that. Not because current models are too limited, but because the knowledge is structurally absent from anything a model could be trained on. That's the actual claim, and it survives scrutiny.

---

## Where I Push Back

The argument assumes that the median junior, given access to an AI assistant, will use it as a replacement for thinking. And honestly? A lot of them will. But that's not a fact about AI. That's a fact about the median junior and the absence of good mentorship. The same junior, given access to Stack Overflow, Google, or a patient senior who answers every question without making them think first, will also atrophy. The crutch varies. The dynamic doesn't.

A good junior understands that AI is a tool to unblock you on things you need to understand, not an infinite knowledge base to stop thinking. The operative word is *understands*. That understanding doesn't come automatically. It has to be built. And that's what the article is really pointing at without quite saying it: the apprenticeship model isn't failing because of AI, it's failing because nobody is teaching juniors how to learn.

Ekrem calls one failure mode the Fluency Mask: AI's verbal fluency about code being mistaken for understanding of code. It's real. But it's a trap that only closes on someone who isn't watching for it. The senior's job has always been to teach juniors to watch for exactly that kind of thing. Confident outputs that feel like understanding but aren't grounded in anything. Stack Overflow answers with high vote counts. Code that compiles. Documentation that reads clearly but documents the wrong thing. AI is a new instance of an old problem.

My son will grow up in a world where AI is as ambient as the internet was for my generation. He won't know a time without it. The question isn't whether he'll use it, he will and he should, but whether he'll use it well or badly. The distinction I want him to carry is simple: AI is a tool to resolve a specific gap, not a replacement for developing the judgment to know where the gap is. Think first. Reach when stuck. Understand what you got back. Inverting that sequence is where the damage happens.

---

## Building the Muscle

The most important window is before he can fluently use AI, which is shrinking fast. The cognitive capacity I want him to develop is tolerance for not-knowing: the ability to sit with an unresolved problem without immediately reaching for relief. Everything downstream of that, debugging, reasoning, designing, the smell that something is wrong before you can name what, depends on being able to stay in the discomfort long enough to actually think.

The way to build that tolerance is not by explaining it. It's by not rescuing him. When he's stuck, the temptation is to solve it. Resist it. Sit with him in the stuck. Ask questions that point at the problem without resolving it. Let him feel the friction. That discomfort is the exercise. Skipping it is skipping the rep.

When AI is in the picture, I want to use it with him out loud, narrating why I'm reaching for it. "I know what I want here but I've forgotten the syntax, I'll check" is different from "I don't know what I want yet, so I need to think before I ask anything." He needs to see that distinction made consciously, by someone he trusts, before it becomes instinct.

After he's worked through something, I want to ask him to explain it back. Not as a test. As genuine curiosity. The act of explanation forces him to consolidate what he actually understood versus what he pattern-matched. The gaps surface immediately. He'll say something and pause because he doesn't actually know why it works that way. That pause is the whole point. Recognising it as a gap rather than papering over it with confident-sounding words is the habit I want him to have.

---

## The Actual Apprenticeship

The most direct version of all of this is the simplest: when I'm working through something, a problem, a piece of code, a decision, let him watch sometimes. Not to teach him the domain. To show him what thinking looks like. The false starts. The "hmm, that's not right." The moment something clicks. Most kids never see an adult genuinely wrestling with a hard problem because adults hide the struggle. Showing him the struggle, including my own uncertainty, is probably the most valuable thing I can do.

The threat isn't AI. The threat is the absence of people willing to do the slow work of the apprenticeship model: to let juniors watch them think, to push back on "I don't know why but trust me," to pair and review and explain. AI makes the shortcut more available and more seductive. But the shortcut was always there. The question was always whether someone cared enough to make you take the longer road.

For my son, that's the job. Not to keep him away from AI, that ship has sailed and the destination is fine, but to make sure he gets enough reps on the longer road first that he knows what it feels like and why it's worth walking.

The kids who figure that out will be the ones the next generation of teams desperately needs.

---

*Inspired by [The Tacit Dimension](https://cekrem.github.io/posts/the-tacit-dimension/) by Christian Ekrem, and by a conversation with an AI assistant that was, appropriately, more useful than I expected.*
