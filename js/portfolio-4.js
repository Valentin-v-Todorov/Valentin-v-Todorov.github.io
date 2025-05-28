// 🚀 ENHANCED CALISTHENICS ANIMATION SYSTEM 🚀

// Main scroll-triggered animations
function initScrollAnimations() {
	const observerOptions = {
		threshold: 0.1,
		rootMargin: '0px 0px -50px 0px'
	};

	const observer = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('revealed');
			}
		});
	}, observerOptions);

	document.querySelectorAll('.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right').forEach(el => {
		observer.observe(el);
	});
}

// Workout sections staggered animation
function initWorkoutAnimations() {
	const workoutSections = document.querySelectorAll('.workout-section');

	const workoutObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate exercise cards within the section
					const exerciseCards = entry.target.querySelectorAll('.exercise-card');
					exerciseCards.forEach((card, i) => {
						setTimeout(() => {
							card.classList.add('animate');

							// Animate table rows
							const tableRows = card.querySelectorAll('table tr');
							tableRows.forEach((row, j) => {
								setTimeout(() => {
									row.classList.add('animate');
								}, j * 100);
							});

							// Animate section headers
							const header = card.querySelector('h4');
							if (header) {
								setTimeout(() => {
									header.classList.add('animate');
								}, 150);
							}
						}, i * 200);
					});

					// Animate list items
					const listItems = entry.target.querySelectorAll('ul li');
					listItems.forEach((item, i) => {
						setTimeout(() => {
							item.classList.add('animate');
						}, i * 100 + 300);
					});
				}, index * 150);
			}
		});
	}, { threshold: 0.2 });

	workoutSections.forEach(section => {
		workoutObserver.observe(section);
	});
}

// Content stagger animation system
function initContentStagger() {
	const contentElements = document.querySelectorAll('.content-stagger');

	const contentObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');
				}, index * 200);
			}
		});
	}, { threshold: 0.1 });

	contentElements.forEach(element => {
		contentObserver.observe(element);
	});
}

// Sidebar sections animation with skill levels
function initSidebarAnimations() {
	const sidebarSections = document.querySelectorAll('.sidebar-section');

	const sidebarObserver = new IntersectionObserver((entries) => {
		entries.forEach((entry, index) => {
			if (entry.isIntersecting) {
				setTimeout(() => {
					entry.target.classList.add('animate');

					// Animate skill level tags
					const skillLevels = entry.target.querySelectorAll('.skill-level');
					skillLevels.forEach((skill, i) => {
						setTimeout(() => {
							skill.classList.add('animate');
						}, i * 100);
					});

					// Animate tech fitness list items
					const techItems = entry.target.querySelectorAll('.tech-fitness-list li');
					techItems.forEach((item, i) => {
						setTimeout(() => {
							item.classList.add('animate');
						}, i * 150);
					});

					// Animate skill items and progress bars
					const skillItems = entry.target.querySelectorAll('.skill-item');
					skillItems.forEach((item, i) => {
						setTimeout(() => {
							item.classList.add('animate');

							// Animate progress bar
							const progressBar = item.querySelector('.progress-fill');
							if (progressBar) {
								const targetWidth = progressBar.getAttribute('data-width');
								setTimeout(() => {
									progressBar.style.width = targetWidth + '%';
									progressBar.classList.add('animate');
								}, 300);
							}
						}, i * 200);
					});
				}, index * 200);
			}
		});
	}, { threshold: 0.3 });

	sidebarSections.forEach(section => {
		sidebarObserver.observe(section);
	});
}

// Philosophy quote animation
function initPhilosophyAnimation() {
	const quotes = document.querySelectorAll('.philosophy-quote');

	const quoteObserver = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (entry.isIntersecting) {
				entry.target.classList.add('animate');
			}
		});
	}, { threshold: 0.3 });

	quotes.forEach(quote => {
		quoteObserver.observe(quote);
	});
}

// Enhanced 3D hover effects for sidebar sections
function initSidebar3DEffects() {
	document.querySelectorAll('.sidebar-section').forEach(section => {
		section.addEventListener('mousemove', (e) => {
			const rect = section.getBoundingClientRect();
			const x = e.clientX - rect.left;
			const y = e.clientY - rect.top;
			const centerX = rect.width / 2;
			const centerY = rect.height / 2;
			const deltaX = (x - centerX) / 15;
			const deltaY = (y - centerY) / 15;

			section.style.transform = `
				perspective(1000px)
				rotateX(${deltaY}deg)
				rotateY(${deltaX}deg)
				translateZ(10px)
				scale(1.02)
			`;
		});

		section.addEventListener('mouseleave', () => {
			section.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateZ(0) scale(1)';
		});
	});
}

// Skill level tag interactive effects
function initSkillTagEffects() {
	document.querySelectorAll('.skill-level').forEach(tag => {
		tag.addEventListener('click', function(e) {
			// Create ripple effect
			const ripple = document.createElement('span');
			const rect = this.getBoundingClientRect();
			const size = Math.max(rect.width, rect.height);
			const x = e.clientX - rect.left - size / 2;
			const y = e.clientY - rect.top - size / 2;

			ripple.style.cssText = `
				position: absolute;
				border-radius: 50%;
				background: rgba(255, 255, 255, 0.6);
				transform: scale(0);
				animation: ripple 0.6s linear;
				width: ${size}px;
				height: ${size}px;
				left: ${x}px;
				top: ${y}px;
				pointer-events: none;
			`;

			this.appendChild(ripple);

			setTimeout(() => {
				ripple.remove();
			}, 600);
		});
	});

	// Add ripple animation CSS
	if (!document.querySelector('#ripple-styles')) {
		const style = document.createElement('style');
		style.id = 'ripple-styles';
		style.textContent = `
			@keyframes ripple {
				to {
					transform: scale(4);
					opacity: 0;
				}
			}
		`;
		document.head.appendChild(style);
	}
}

// Exercise card hover effects
function initExerciseCardEffects() {
	document.querySelectorAll('.exercise-card').forEach(card => {
		card.addEventListener('mouseenter', function() {
			this.style.transform = 'translateX(10px)';
			this.style.background = '#4a4a4a';
			this.style.boxShadow = '0 10px 25px rgba(255, 107, 107, 0.2)';
		});

		card.addEventListener('mouseleave', function() {
			this.style.transform = 'translateX(0)';
			this.style.background = '#444';
			this.style.boxShadow = '';
		});
	});
}

// Parallax scrolling effect for header
function initParallaxEffect() {
	window.addEventListener('scroll', () => {
		const scrolled = window.pageYOffset;
		const header = document.querySelector('.project-header');
		if (header) {
			header.style.transform = `translateY(${scrolled * 0.3}px)`;
		}
	});
}

// Enhanced navigation effects
function initNavigationEffects() {
	const navLinks = document.querySelectorAll('.nav-links a');
	navLinks.forEach(link => {
		link.addEventListener('mouseenter', function() {
			this.style.transform = 'translateY(-2px) scale(1.05)';
			this.style.boxShadow = '0 5px 15px rgba(255, 107, 107, 0.4)';
		});
		link.addEventListener('mouseleave', function() {
			if (!this.classList.contains('active')) {
				this.style.transform = 'translateY(0) scale(1)';
				this.style.boxShadow = '';
			}
		});
	});
}

// Table row progressive animation
function initTableAnimations() {
	const tables = document.querySelectorAll('.exercise-card table');

	tables.forEach(table => {
		const rows = table.querySelectorAll('tr');

		const tableObserver = new IntersectionObserver((entries) => {
			entries.forEach(entry => {
				if (entry.isIntersecting) {
					const tableRows = entry.target.querySelectorAll('tr');
					tableRows.forEach((row, index) => {
						setTimeout(() => {
							row.style.opacity = '1';
							row.style.transform = 'translateY(0)';
						}, index * 100);
					});
				}
			});
		}, { threshold: 0.3 });

		tableObserver.observe(table);
	});
}

// Smooth page loading animation
function initPageLoadAnimation() {
	document.body.style.opacity = '0';
	document.body.style.transition = 'opacity 0.5s ease';

	setTimeout(() => {
		document.body.style.opacity = '1';
	}, 100);
}

// Initialize all animations when page loads
document.addEventListener('DOMContentLoaded', function() {
	initPageLoadAnimation();

	// Delay animation initialization for smooth loading
	setTimeout(() => {
		initScrollAnimations();
		initWorkoutAnimations();
		initContentStagger();
		initSidebarAnimations();
		initPhilosophyAnimation();
		initSidebar3DEffects();
		initSkillTagEffects();
		initExerciseCardEffects();
		initParallaxEffect();
		initNavigationEffects();
		initTableAnimations();

		// Add loaded class for final touches
		document.body.classList.add('animations-loaded');
	}, 150);
});

// Add smooth scrolling for anchor links
document.addEventListener('DOMContentLoaded', function() {
	document.querySelectorAll('a[href^="#"]').forEach(anchor => {
		anchor.addEventListener('click', function (e) {
			e.preventDefault();
			const target = document.querySelector(this.getAttribute('href'));
			if (target) {
				target.scrollIntoView({
					behavior: 'smooth',
					block: 'start'
				});
			}
		});
	});
});